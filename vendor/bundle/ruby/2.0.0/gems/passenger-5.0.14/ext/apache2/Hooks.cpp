/*
 *  Phusion Passenger - https://www.phusionpassenger.com/
 *  Copyright (c) 2010-2015 Phusion
 *
 *  "Phusion Passenger" is a trademark of Hongli Lai & Ninh Bui.
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a copy
 *  of this software and associated documentation files (the "Software"), to deal
 *  in the Software without restriction, including without limitation the rights
 *  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *  copies of the Software, and to permit persons to whom the Software is
 *  furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice shall be included in
 *  all copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 *  THE SOFTWARE.
 */

/*
 * This is the main source file which interfaces directly with Apache by
 * installing hooks. The code here can look a bit convoluted, but it'll make
 * more sense if you read:
 * http://httpd.apache.org/docs/2.2/developer/request.html
 *
 * Scroll all the way down to passenger_register_hooks to get an idea of
 * what we're hooking into and what we do in those hooks. There are many
 * hooks but the gist is implemented in just two methods: prepareRequest()
 * and handleRequest(). Most hooks exist for implementing compatibility
 * with other Apache modules. These hooks create an environment in which
 * prepareRequest() and handleRequest() can be comfortably run.
 */

#include <boost/thread.hpp>

#include <sys/time.h>
#include <sys/resource.h>
#include <exception>
#include <cstdio>
#include <unistd.h>

#include <oxt/initialize.hpp>
#include <oxt/macros.hpp>
#include <oxt/backtrace.hpp>
#include <oxt/detail/context.hpp>
#include "Hooks.h"
#include "Bucket.h"
#include "Configuration.hpp"
#include "DirectoryMapper.h"
#include <Utils.h>
#include <Utils/IOUtils.h>
#include <Utils/StrIntUtils.h>
#include <Utils/Timer.h>
#include <Utils/HttpConstants.h>
#include <Utils/modp_b64.h>
#include <Logging.h>
#include <AgentsStarter.h>
#include <Constants.h>

/* The Apache/APR headers *must* come after the Boost headers, otherwise
 * compilation will fail on OpenBSD.
 */
#include <ap_config.h>
#include <ap_release.h>
#include <httpd.h>
#include <http_config.h>
#include <http_core.h>
#include <http_request.h>
#include <http_protocol.h>
#include <http_log.h>
#include <util_script.h>
#include <apr_pools.h>
#include <apr_strings.h>
#include <apr_lib.h>
#include <unixd.h>

using namespace std;
using namespace Passenger;

extern "C" module AP_MODULE_DECLARE_DATA passenger_module;

#ifdef APLOG_USE_MODULE
	APLOG_USE_MODULE(passenger);
#endif

#if HTTP_VERSION(AP_SERVER_MAJORVERSION_NUMBER, AP_SERVER_MINORVERSION_NUMBER) > 2002
	// Apache > 2.2.x
	#define AP_GET_SERVER_VERSION_DEPRECATED
#elif HTTP_VERSION(AP_SERVER_MAJORVERSION_NUMBER, AP_SERVER_MINORVERSION_NUMBER) == 2002
	// Apache == 2.2.x
	#if AP_SERVER_PATCHLEVEL_NUMBER >= 14
		#define AP_GET_SERVER_VERSION_DEPRECATED
	#endif
#endif


/**
 * Apache hook functions, wrapped in a class.
 *
 * @ingroup Core
 */
class Hooks {
private:
	class ErrorReport {
	public:
		virtual ~ErrorReport() { }
		virtual int report(request_rec *r) = 0;
	};

	class ReportFileSystemError: public ErrorReport {
	private:
		FileSystemException e;

		#ifdef __linux__
			bool selinuxIsEnforcing() const {
				FILE *f = fopen("/sys/fs/selinux/enforce", "r");
				if (f != NULL) {
					char buf;
					size_t ret = fread(&buf, 1, 1, f);
					fclose(f);
					return ret == 1 && buf == '1';
				} else {
					return false;
				}
			}
		#endif

	public:
		ReportFileSystemError(const FileSystemException &ex): e(ex) { }

		int report(request_rec *r) {
			r->status = 500;
			ap_set_content_type(r, "text/html; charset=UTF-8");
			ap_rputs("<h1>Passenger error #2</h1>\n", r);
			ap_rputs("<p>An error occurred while trying to access '", r);
			ap_rputs(ap_escape_html(r->pool, e.filename().c_str()), r);
			ap_rputs("': ", r);
			ap_rputs(ap_escape_html(r->pool, e.what()), r);
			ap_rputs("</p>\n", r);

			if (e.code() == EACCES || e.code() == EPERM) {
				ap_rputs("<p>", r);
				ap_rputs("Apache doesn't have read permissions to that file. ", r);
				ap_rputs("Please fix the relevant file permissions.", r);
				ap_rputs("</p>\n", r);
				#ifdef __linux__
					if (selinuxIsEnforcing()) {
						ap_rputs("<p>", r);
						ap_rputs("The permission problems may also be caused by SELinux restrictions. ", r);
						ap_rputs("Please read " APACHE2_DOC_URL "#apache_selinux_permissions to learn ", r);
						ap_rputs("how to fix SELinux permission issues. ", r);
						ap_rputs("</p>", r);
					}
				#endif
			}

			P_ERROR("A filesystem exception occured.\n" <<
				"  Message: " << e.what() << "\n" <<
				"  Backtrace:\n" << e.backtrace());
			return OK;
		}
	};

	class ReportDocumentRootDeterminationError: public ErrorReport {
	private:
		DocumentRootDeterminationError e;

	public:
		ReportDocumentRootDeterminationError(const DocumentRootDeterminationError &ex): e(ex) { }

		int report(request_rec *r) {
			r->status = 500;
			ap_set_content_type(r, "text/html; charset=UTF-8");
			ap_rputs("<h1>Passenger error #1</h1>\n", r);
			ap_rputs("Cannot determine the document root for the current request.", r);
			P_ERROR("Cannot determine the document root for the current request.\n" <<
				"  Backtrace:\n" << e.backtrace());
			return OK;
		}
	};

	struct RequestNote {
		DirectoryMapper mapper;
		DirConfig *config;
		ErrorReport *errorReport;

		const char *handlerBeforeModRewrite;
		char *filenameBeforeModRewrite;
		apr_filetype_e oldFileType;
		const char *handlerBeforeModAutoIndex;
		bool enabled;

		RequestNote(const DirectoryMapper &m, DirConfig *c)
			: mapper(m),
			  config(c)
		{
			errorReport      = NULL;
			handlerBeforeModRewrite   = NULL;
			filenameBeforeModRewrite  = NULL;
			oldFileType               = APR_NOFILE;
			handlerBeforeModAutoIndex = NULL;
			enabled                   = true;
		}

		~RequestNote() {
			delete errorReport;
		}

		static apr_status_t cleanup(void *p) {
			delete (RequestNote *) p;
			return APR_SUCCESS;
		}
	};

	enum Threeway { YES, NO, UNKNOWN };

	Threeway m_hasModRewrite, m_hasModDir, m_hasModAutoIndex, m_hasModXsendfile;
	CachedFileStat cstat;
	AgentsStarter agentsStarter;
	boost::mutex cstatMutex;

	inline DirConfig *getDirConfig(request_rec *r) {
		return (DirConfig *) ap_get_module_config(r->per_dir_config, &passenger_module);
	}

	/**
	 * The existance of a request note means that the handler should be run.
	 */
	inline RequestNote *getRequestNote(request_rec *r) {
		void *pointer = 0;
		apr_pool_userdata_get(&pointer, "Phusion Passenger", r->pool);
		if (pointer != NULL) {
			RequestNote *note = (RequestNote *) pointer;
			if (OXT_LIKELY(note->enabled)) {
				return note;
			} else {
				return 0;
			}
		} else {
			return 0;
		}
	}

	void disableRequestNote(request_rec *r) {
		RequestNote *note = getRequestNote(r);
		if (note != NULL) {
			note->enabled = false;
		}
	}

	StaticString getCoreAddress() const {
		return agentsStarter.getCoreAddress();
	}

	StaticString getCorePassword() const {
		return agentsStarter.getCorePassword();
	}

	/**
	 * Connect to the Passenger core. If it looks like the core crashed,
	 * wait and retry for a short period of time until the core has been
	 * restarted by the watchdog.
	 */
	FileDescriptor connectToInternalServer() {
		TRACE_POINT();
		FileDescriptor conn;

		try {
			conn.assign(connectToServer(getCoreAddress(), __FILE__, __LINE__), NULL, 0);
		} catch (const SystemException &e) {
			if (e.code() == EPIPE || e.code() == ECONNREFUSED || e.code() == ENOENT) {
				UPDATE_TRACE_POINT();
				bool connected = false;

				// Maybe the core crashed. First wait 50 ms.
				usleep(50000);

				// Then try to reconnect to the core for the
				// next 5 seconds.
				time_t deadline = time(NULL) + 5;
				while (!connected && time(NULL) < deadline) {
					try {
						conn.assign(connectToServer(getCoreAddress(), __FILE__, __LINE__), NULL, 0);
						connected = true;
					} catch (const SystemException &e) {
						if (e.code() == EPIPE || e.code() == ECONNREFUSED || e.code() == ENOENT) {
							// Looks like the core hasn't been
							// restarted yet. Wait between 20 and 100 ms.
							usleep(20000 + rand() % 80000);
							// Don't care about thread-safety of rand()
						} else {
							throw;
						}
					}
				}

				if (!connected) {
					UPDATE_TRACE_POINT();
					throw IOException("Cannot connect to the Passenger core at " +
						getCoreAddress());
				}
			} else {
				throw;
			}
		}
		return conn;
	}

	vector<string> getConfigFiles(server_rec *s) const {
		server_rec *server;
		vector<string> result;

		for (server = s; server != NULL; server = server->next) {
			if (server->defn_name != NULL) {
				result.push_back(server->defn_name);
			}
		}

		return result;
	}

	bool hasModRewrite() {
		if (m_hasModRewrite == UNKNOWN) {
			if (ap_find_linked_module("mod_rewrite.c")) {
				m_hasModRewrite = YES;
			} else {
				m_hasModRewrite = NO;
			}
		}
		return m_hasModRewrite == YES;
	}

	bool hasModDir() {
		if (m_hasModDir == UNKNOWN) {
			if (ap_find_linked_module("mod_dir.c")) {
				m_hasModDir = YES;
			} else {
				m_hasModDir = NO;
			}
		}
		return m_hasModDir == YES;
	}

	bool hasModAutoIndex() {
		if (m_hasModAutoIndex == UNKNOWN) {
			if (ap_find_linked_module("mod_autoindex.c")) {
				m_hasModAutoIndex = YES;
			} else {
				m_hasModAutoIndex = NO;
			}
		}
		return m_hasModAutoIndex == YES;
	}

	bool hasModXsendfile() {
		if (m_hasModXsendfile == UNKNOWN) {
			if (ap_find_linked_module("mod_xsendfile.c")) {
				m_hasModXsendfile = YES;
			} else {
				m_hasModXsendfile = NO;
			}
		}
		return m_hasModXsendfile == YES;
	}

	int reportBusyException(request_rec *r) {
		ap_custom_response(r, HTTP_SERVICE_UNAVAILABLE,
			"This website is too busy right now.  Please try again later.");
		return HTTP_SERVICE_UNAVAILABLE;
	}

	/**
	 * Gather some information about the request and do some preparations.
	 *
	 * This method will determine whether the Phusion Passenger handler method
	 * should be run for this request, through the following checks:
	 * (B) There is a backend application defined for this URI.
	 * (C) r->filename already exists, meaning that this URI already maps to an existing file.
	 * (D) There is a page cache file for this URI.
	 *
	 * - If B is not true, or if C is true, then the handler shouldn't be run.
	 * - If D is true, then we first transform r->filename to the page cache file's
	 *   filename, and then we let Apache serve it statically. The Phusion Passenger
	 *   handler shouldn't be run.
	 * - If D is not true, then the handler should be run.
	 *
	 * @pre config->isEnabled()
	 * @param coreModuleWillBeRun Whether the core.c map_to_storage hook might be called after this.
	 * @return Whether the Phusion Passenger handler hook method should be run.
	 *         When true, this method will save a request note object so that future hooks
	 *         can store request-specific information.
	 */
	bool prepareRequest(request_rec *r, DirConfig *config, const char *filename, bool coreModuleWillBeRun = false) {
		TRACE_POINT();

		DirectoryMapper mapper(r, config, &cstat, &cstatMutex, serverConfig.statThrottleRate);
		try {
			if (mapper.getApplicationType() == PAT_NONE) {
				// (B) is not true.
				disableRequestNote(r);
				return false;
			}
		} catch (const DocumentRootDeterminationError &e) {
			auto_ptr<RequestNote> note(new RequestNote(mapper, config));
			note->errorReport = new ReportDocumentRootDeterminationError(e);
			apr_pool_userdata_set(note.release(), "Phusion Passenger",
				RequestNote::cleanup, r->pool);
			return true;
		} catch (const FileSystemException &e) {
			/* DirectoryMapper tried to examine the filesystem in order
			 * to autodetect the application type (e.g. by checking whether
			 * environment.rb exists. But something went wrong, probably
			 * because of a permission problem. This usually
			 * means that the user is trying to deploy an application, but
			 * set the wrong permissions on the relevant folders.
			 * Later, in the handler hook, we inform the user about this
			 * problem so that he can either disable Phusion Passenger's
			 * autodetection routines, or fix the permissions.
			 *
			 * If it's not a permission problem then we'll disable
			 * Phusion Passenger for the rest of the request.
			 */
			if (e.code() == EACCES || e.code() == EPERM) {
				auto_ptr<RequestNote> note(new RequestNote(mapper, config));
				note->errorReport = new ReportFileSystemError(e);
				apr_pool_userdata_set(note.release(), "Phusion Passenger",
					RequestNote::cleanup, r->pool);
				return true;
			} else {
				disableRequestNote(r);
				return false;
			}
		}

		// (B) is true.

		try {
			FileType fileType = getFileType(filename);
			if (fileType == FT_REGULAR) {
				// (C) is true.
				disableRequestNote(r);
				return false;
			}

			// (C) is not true. Check whether (D) is true.
			char *pageCacheFile;
			/* Only GET requests may hit the page cache. This is
			 * important because of REST conventions, e.g.
			 * 'POST /foo' maps to 'FooController#create',
			 * while 'GET /foo' maps to 'FooController#index'.
			 * We wouldn't want our page caching support to interfere
			 * with that.
			 */
			if (r->method_number == M_GET) {
				if (fileType == FT_DIRECTORY) {
					size_t len;

					len = strlen(filename);
					if (len > 0 && filename[len - 1] == '/') {
						pageCacheFile = apr_pstrcat(r->pool, filename,
							"index.html", (char *) NULL);
					} else {
						pageCacheFile = apr_pstrcat(r->pool, filename,
							".html", (char *) NULL);
					}
				} else {
					pageCacheFile = apr_pstrcat(r->pool, filename,
						".html", (char *) NULL);
				}
				if (!fileExists(pageCacheFile)) {
					pageCacheFile = NULL;
				}
			} else {
				pageCacheFile = NULL;
			}
			if (pageCacheFile != NULL) {
				// (D) is true.
				r->filename = pageCacheFile;
				r->canonical_filename = pageCacheFile;
				if (!coreModuleWillBeRun) {
					r->finfo.filetype = APR_NOFILE;
					ap_set_content_type(r, "text/html");
					ap_directory_walk(r);
					ap_file_walk(r);
				}
				return false;
			} else {
				// (D) is not true.
				RequestNote *note = new RequestNote(mapper, config);
				apr_pool_userdata_set(note, "Phusion Passenger",
					RequestNote::cleanup, r->pool);
				return true;
			}
		} catch (const FileSystemException &e) {
			/* Something went wrong while accessing the directory in which
			 * r->filename lives. We already know that this URI belongs to
			 * a backend application, so this error probably means that the
			 * user set the wrong permissions for his 'public' folder. We
			 * don't let the handler hook run so that Apache can decide how
			 * to display the error.
			 */
			disableRequestNote(r);
			return false;
		}
	}

	/**
	 * Most of the high-level logic for forwarding a request to the
	 * Passenger core is contained in this method.
	 */
	int handleRequest(request_rec *r) {
		/********** Step 1: preparation work **********/

		/* Initialize OXT backtrace support if not already done for this thread */
		if (oxt::get_thread_local_context() == NULL) {
			/* There is no need to cleanup the context. Apache uses a static
			 * number of threads per process.
			 */
			thread_local_context_ptr context = thread_local_context::make_shared_ptr();
			unsigned long tid = (unsigned long) pthread_self();
			context->thread_name = "Worker " + integerToHex(tid);
			oxt::set_thread_local_context(context);
		}

		/* Check whether an error occured in prepareRequest() that should be reported
		 * to the browser.
		 */

		RequestNote *note = getRequestNote(r);
		if (note == NULL) {
			return DECLINED;
		} else if (note->errorReport != NULL) {
			/* Did an error occur in any of the previous hook methods during
			 * this request? If so, show the error and stop here.
			 */
			return note->errorReport->report(r);
		} else if (r->handler != NULL && strcmp(r->handler, "redirect-handler") == 0) {
			// mod_rewrite is at work.
			return DECLINED;
		}

		/* mod_mime might have set the httpd/unix-directory Content-Type
		 * if it detects that the current URL maps to a directory. We do
		 * not want to preserve that Content-Type.
		 */
		ap_set_content_type(r, NULL);

		TRACE_POINT();
		DirConfig *config = note->config;
		DirectoryMapper &mapper = note->mapper;

		try {
			mapper.getPublicDirectory();
		} catch (const DocumentRootDeterminationError &e) {
			return ReportDocumentRootDeterminationError(e).report(r);
		} catch (const FileSystemException &e) {
			/* The application root cannot be determined. This could
			 * happen if, for example, the user specified 'RailsBaseURI /foo'
			 * while there is no filesystem entry called "foo" in the virtual
			 * host's document root.
			 */
			return ReportFileSystemError(e).report(r);
		}


		UPDATE_TRACE_POINT();
		try {
			/********** Step 2: handle HTTP upload data, if any **********/

			int httpStatus = ap_setup_client_block(r, REQUEST_CHUNKED_DECHUNK);
	    	if (httpStatus != OK) {
				return httpStatus;
			}

			this_thread::disable_interruption di;
			this_thread::disable_syscall_interruption dsi;
			bool expectingBody;

			expectingBody = ap_should_client_block(r);


			/********** Step 3: forwarding the request and request body
			                    to the Passenger core **********/

			int ret;
			bool bodyIsChunked = false;

			string headers = constructRequestHeaders(r, mapper, bodyIsChunked);
			FileDescriptor conn = connectToInternalServer();
			writeExact(conn, headers);
			headers.clear();
			if (expectingBody) {
				sendRequestBody(conn, r, bodyIsChunked);
			}


			/********** Step 4: forwarding the response from the Passenger core
			                    back to the HTTP client **********/

			UPDATE_TRACE_POINT();
			apr_bucket_brigade *bb;
			apr_bucket *b;
			PassengerBucketStatePtr bucketState;

			/* Setup the bucket brigade. */
			bb = apr_brigade_create(r->connection->pool, r->connection->bucket_alloc);

			bucketState = boost::make_shared<PassengerBucketState>(conn);
			b = passenger_bucket_create(bucketState, r->connection->bucket_alloc,
				config->getBufferResponse());
			APR_BRIGADE_INSERT_TAIL(bb, b);

			b = apr_bucket_eos_create(r->connection->bucket_alloc);
			APR_BRIGADE_INSERT_TAIL(bb, b);

			/* Now read the HTTP response header, parse it and fill relevant
			 * information in our request_rec structure. We skip the status line
			 * because ap_scan_script_header_err_brigade() can't handle it.
			 */

			/* I know the required size for backendData because I read
			 * util_script.c's source. :-(
			 */
			char backendData[MAX_STRING_LEN];
			Timer timer;
			getsfunc_BRIGADE(backendData, MAX_STRING_LEN, bb);

			// The bucket brigade is an interface to the HTTP response sent by the
			// PassengerAgent. The scanner parses (line by line) response headers
			// into error_headers_out (mostly) as well as headers_out.
			ret = ap_scan_script_header_err_brigade(r, bb, backendData);

			// The PassengerAgent sets the Connection: close header because it wants
			// the bb connection closed, but because we fed everything to the
			// ap_scan_script it will also be set in the response to the client and
			// that breaks HTTP 1.1 keep-alive, so unset it.
			apr_table_unset(r->err_headers_out, "Connection");
			// It's undefined in which of the tables it ends up in, so unset on both.
			apr_table_unset(r->headers_out, "Connection");

			if (ret == OK) {
				// The API documentation for ap_scan_script_err_brigade() says it
				// returns HTTP_OK on success, but it actually returns OK.

				/* We were able to parse the HTTP response header sent by the
				 * backend process! Proceed with passing the bucket brigade,
				 * for forwarding the response body to the HTTP client.
				 */

				/* Manually set the Status header because
				 * ap_scan_script_header_err_brigade() filters it
				 * out. Some broken HTTP clients depend on the
				 * Status header for retrieving the HTTP status.
				 */
				if (!r->status_line || *r->status_line == '\0') {
					r->status_line = getStatusCodeAndReasonPhrase(r->status);
					if (r->status_line == NULL) {
						r->status_line = apr_psprintf(r->pool,
							"%d Unknown Status",
							r->status);
					}
				}
				apr_table_setn(r->headers_out, "Status", r->status_line);

				UPDATE_TRACE_POINT();
				if (config->errorOverride == DirConfig::ENABLED
				 && ap_is_HTTP_ERROR(r->status))
				{
					/* Send ErrorDocument.
					 * Clear r->status for override error, otherwise ErrorDocument
					 * thinks that this is a recursive error, and doesn't find the
					 * custom error page.
					 */
					int originalStatus = r->status;
					r->status = HTTP_OK;
					return originalStatus;
				} else if (ap_pass_brigade(r->output_filters, bb) == APR_SUCCESS) {
					apr_brigade_cleanup(bb);
				}
				return OK;
			} else {
				// Passenger core sent an empty response, or an invalid response.
				apr_brigade_cleanup(bb);
				apr_table_setn(r->err_headers_out, "Status", "500 Internal Server Error");
				return HTTP_INTERNAL_SERVER_ERROR;
			}

		} catch (const thread_interrupted &e) {
			P_TRACE(3, "A system call was interrupted during an HTTP request. Apache "
				"is probably restarting or shutting down. Backtrace:\n" <<
				e.backtrace());
			return HTTP_INTERNAL_SERVER_ERROR;

		} catch (const tracable_exception &e) {
			P_ERROR("Unexpected error in mod_passenger: " <<
				e.what() << "\n" << "  Backtrace:\n" << e.backtrace());
			return HTTP_INTERNAL_SERVER_ERROR;

		} catch (const std::exception &e) {
			P_ERROR("Unexpected error in mod_passenger: " <<
				e.what() << "\n" << "  Backtrace: not available");
			return HTTP_INTERNAL_SERVER_ERROR;
		}
	}

	unsigned int
	escapeUri(unsigned char *dst, const unsigned char *src, size_t size) {
		static const char hex[] = "0123456789abcdef";
			           /* " ", "#", "%", "?", %00-%1F, %7F-%FF */
		static uint32_t escape[] = {
		       0xffffffff, /* 1111 1111 1111 1111  1111 1111 1111 1111 */

		                   /* ?>=< ;:98 7654 3210  /.-, +*)( '&%$ #"!  */
		       0x80000029, /* 1000 0000 0000 0000  0000 0000 0010 1001 */

		                   /* _^]\ [ZYX WVUT SRQP  ONML KJIH GFED CBA@ */
		       0x00000000, /* 0000 0000 0000 0000  0000 0000 0000 0000 */

		                   /*  ~}| {zyx wvut srqp  onml kjih gfed cba` */
		       0x80000000, /* 1000 0000 0000 0000  0000 0000 0000 0000 */

		       0xffffffff, /* 1111 1111 1111 1111  1111 1111 1111 1111 */
		       0xffffffff, /* 1111 1111 1111 1111  1111 1111 1111 1111 */
		       0xffffffff, /* 1111 1111 1111 1111  1111 1111 1111 1111 */
		       0xffffffff  /* 1111 1111 1111 1111  1111 1111 1111 1111 */
		};

		if (dst == NULL) {
			/* find the number of the characters to be escaped */
			unsigned int n = 0;
			while (size > 0) {
				if (escape[*src >> 5] & (1 << (*src & 0x1f))) {
					n++;
				}
				src++;
				size--;
			}
			return n;
		}

		while (size > 0) {
			if (escape[*src >> 5] & (1 << (*src & 0x1f))) {
				*dst++ = '%';
				*dst++ = hex[*src >> 4];
				*dst++ = hex[*src & 0xf];
				src++;
			} else {
				*dst++ = *src++;
			}
			size--;
		}
		return 0;
	}

	/**
	 * Convert an HTTP header name to a CGI environment name.
	 */
	char *httpToEnv(apr_pool_t *p, const char *headerName, size_t len) {
		char *result  = apr_pstrcat(p, "HTTP_", headerName, (char *) NULL);
		char *current = result + sizeof("HTTP_") - 1;

		while (*current != '\0') {
			if (*current == '-') {
				*current = '_';
			} else {
				*current = apr_toupper(*current);
			}
			current++;
		}

		return result;
	}

	const char *lookupInTable(apr_table_t *table, const char *name) {
		const apr_array_header_t *headers = apr_table_elts(table);
		apr_table_entry_t *elements = (apr_table_entry_t *) headers->elts;

		for (int i = 0; i < headers->nelts; i++) {
			if (elements[i].key != NULL && strcasecmp(elements[i].key, name) == 0) {
				return elements[i].val;
			}
		}
		return NULL;
	}

	const char *lookupEnv(request_rec *r, const char *name) {
		return lookupInTable(r->subprocess_env, name);
	}

	bool connectionUpgradeFlagSet(const char *header) const {
		size_t headerSize = strlen(header);
		if (headerSize < 1024) {
			char buffer[headerSize + 1];
			return connectionUpgradeFlagSet(header, headerSize, buffer, headerSize + 1);
		} else {
			DynamicBuffer buffer(headerSize + 1);
			return connectionUpgradeFlagSet(header, headerSize, buffer.data, headerSize + 1);
		}
	}

	bool connectionUpgradeFlagSet(const char *header, size_t headerSize,
		char *buffer, size_t bufsize) const
	{
		assert(bufsize > headerSize);
		convertLowerCase((const unsigned char *) header, (unsigned char *) buffer, headerSize);
		buffer[headerSize] = '\0';
		return strstr(buffer, "upgrade");
	}

	void addHeader(string &headers, const StaticString &name, const char *value) {
		if (value != NULL) {
			headers.append(name.data(), name.size());
			headers.append(": ", 2);
			headers.append(value);
			headers.append("\r\n", 2);
		}
	}

	void addHeader(string &headers, const StaticString &name, const StaticString &value) {
		headers.append(name.data(), name.size());
		headers.append(": ", 2);
		headers.append(value.data(), value.size());
		headers.append("\r\n", 2);
	}

	void addHeader(request_rec *r, string &headers, const StaticString &name, int value) {
		if (value != UNSET_INT_VALUE) {
			headers.append(name.data(), name.size());
			headers.append(": ", 2);
			headers.append(apr_psprintf(r->pool, "%d", value));
			headers.append("\r\n", 2);
		}
	}

	void addHeader(string &headers, const StaticString &name, DirConfig::Threeway value) {
		if (value != DirConfig::UNSET) {
			headers.append(name.data(), name.size());
			headers.append(": ", 2);
			if (value == DirConfig::ENABLED) {
				headers.append("t", 1);
			} else {
				headers.append("f", 1);
			}
			headers.append("\r\n", 2);
		}
	}

	string constructRequestHeaders(request_rec *r, DirectoryMapper &mapper,
		bool &bodyIsChunked)
	{
		const char *baseURI = mapper.getBaseURI();
		DirConfig *config = getDirConfig(r);
		string result;

		// Construct HTTP status line.

		result.reserve(4096);
		result.append(r->method);
		result.append(" ", 1);

		if (config->allowsEncodedSlashes()) {
			/*
			 * Apache decodes encoded slashes in r->uri, so we must use r->unparsed_uri
			 * if we are to support encoded slashes. However mod_rewrite doesn't change
			 * r->unparsed_uri, so the user must make a choice between mod_rewrite
			 * support or encoded slashes support. Sucks. :-(
			 *
			 * http://code.google.com/p/phusion-passenger/issues/detail?id=113
			 * http://code.google.com/p/phusion-passenger/issues/detail?id=230
			 */
			result.append(r->unparsed_uri);
		} else {
			size_t uriLen = strlen(r->uri);
			unsigned int escaped = escapeUri(NULL, (const unsigned char *) r->uri, uriLen);
			size_t escapedUriLen = uriLen + 2 * escaped;
			char *escapedUri = (char *) apr_palloc(r->pool, escapedUriLen);
			escapeUri((unsigned char *) escapedUri, (const unsigned char *) r->uri, uriLen);

			result.append(escapedUri, escapedUriLen);

			if (r->args != NULL) {
				result.append("?", 1);
				result.append(r->args);
			}
		}

		result.append(" HTTP/1.1\r\n", sizeof(" HTTP/1.1\r\n") - 1);

		// Construct HTTP headers.

		const apr_array_header_t *hdrs_arr;
		apr_table_entry_t *hdrs;
		apr_table_entry_t *connectionHeader = NULL;
		apr_table_entry_t *transferEncodingHeader = NULL;
		int i;

		hdrs_arr = apr_table_elts(r->headers_in);
		hdrs = (apr_table_entry_t *) hdrs_arr->elts;
		for (i = 0; i < hdrs_arr->nelts; ++i) {
			if (hdrs[i].key == NULL) {
				continue;
			} else if (connectionHeader == NULL
				&& strcasecmp(hdrs[i].key, "Connection") == 0)
			{
				connectionHeader = &hdrs[i];
			} else if (transferEncodingHeader == NULL
				&& strcasecmp(hdrs[i].key, "Transfer-Encoding") == 0)
			{
				transferEncodingHeader = &hdrs[i];
			} else {
				result.append(hdrs[i].key);
				result.append(": ", 2);
				if (hdrs[i].val != NULL) {
					result.append(hdrs[i].val);
				}
				result.append("\r\n", 2);
			}
		}

		if (connectionHeader != NULL && connectionUpgradeFlagSet(connectionHeader->val)) {
			result.append("Connection: upgrade\r\n", sizeof("Connection: upgrade\r\n") - 1);
		} else {
			result.append("Connection: close\r\n", sizeof("Connection: close\r\n") - 1);
		}

		if (transferEncodingHeader != NULL) {
			result.append("Transfer-Encoding: ", sizeof("Transfer-Encoding: ") - 1);
			result.append(transferEncodingHeader->val);
			result.append("\r\n", 2);
			bodyIsChunked = strcasecmp(transferEncodingHeader->val, "chunked") == 0;
		}

		// Add secure headers.

		result.append("!~: ", sizeof("!~: ") - 1);
		result.append(getCorePassword().data(), getCorePassword().size());
		result.append("\r\n!~DOCUMENT_ROOT: ", sizeof("\r\n!~DOCUMENT_ROOT: ") - 1);
		result.append(ap_document_root(r));
		result.append("\r\n", 2);

		if (baseURI != NULL) {
			result.append("!~SCRIPT_NAME: ", sizeof("!~SCRIPT_NAME: ") - 1);
			result.append(baseURI);
			result.append("\r\n", 2);
		}

		#if HTTP_VERSION(AP_SERVER_MAJORVERSION_NUMBER, AP_SERVER_MINORVERSION_NUMBER) >= 2004
			addHeader(result, P_STATIC_STRING("!~REMOTE_ADDR"),
				r->useragent_ip);
			addHeader(r, result, P_STATIC_STRING("!~REMOTE_PORT"),
				r->connection->client_addr->port);
		#else
			addHeader(result, P_STATIC_STRING("!~REMOTE_ADDR"),
				r->connection->remote_ip);
			addHeader(r, result, P_STATIC_STRING("!~REMOTE_PORT"),
				r->connection->remote_addr->port);
		#endif
		addHeader(result, P_STATIC_STRING("!~REMOTE_USER"), r->user);

		// App group name.
		if (config->appGroupName == NULL) {
			result.append("!~PASSENGER_APP_GROUP_NAME: ",
				sizeof("!~PASSENGER_APP_GROUP_NAME: ") - 1);
			result.append(mapper.getAppRoot());
			if (config->appEnv != NULL) {
				result.append(" (", 2);
				result.append(config->appEnv);
				result.append(")", 1);
			}
			result.append("\r\n", 2);
		}

		// Phusion Passenger options.
		addHeader(result, P_STATIC_STRING("!~PASSENGER_APP_ROOT"), mapper.getAppRoot());
		addHeader(result, P_STATIC_STRING("!~PASSENGER_APP_TYPE"), mapper.getApplicationTypeName());
		if (config->useUnionStation() && !config->unionStationKey.empty()) {
			addHeader(result, P_STATIC_STRING("!~UNION_STATION_SUPPORT"), P_STATIC_STRING("t"));
			addHeader(result, P_STATIC_STRING("!~UNION_STATION_KEY"), config->unionStationKey);
			if (!config->unionStationFilters.empty()) {
				addHeader(result, P_STATIC_STRING("!~UNION_STATION_FILTERS"),
					config->getUnionStationFilterString());
			}
		}
		#include "SetHeaders.cpp"

		/*********************/
		/*********************/

		// Add environment variables.

		const apr_array_header_t *env_arr;
		env_arr = apr_table_elts(r->subprocess_env);

		if (env_arr->nelts > 0) {
			apr_table_entry_t *env;
			string envvarsData;
			char *envvarsBase64Data;
			size_t envvarsBase64Len;

			env = (apr_table_entry_t*) env_arr->elts;

			for (i = 0; i < env_arr->nelts; ++i) {
				envvarsData.append(env[i].key);
				envvarsData.append("\0", 1);
				if (env[i].val != NULL) {
					envvarsData.append(env[i].val);
				}
				envvarsData.append("\0", 1);
			}

			envvarsBase64Data = (char *) malloc(modp_b64_encode_len(
				envvarsData.size()));
			if (envvarsBase64Data == NULL) {
				throw RuntimeException("Unable to allocate memory for base64 "
					"encoding of environment variables");
			}
			envvarsBase64Len = modp_b64_encode(envvarsBase64Data,
				envvarsData.data(), envvarsData.size());
			if (envvarsBase64Len == (size_t) -1) {
				free(envvarsBase64Data);
				throw RuntimeException("Unable to base64 encode environment variables");
			}

			result.append("!~PASSENGER_ENV_VARS: ", sizeof("!~PASSENGER_ENV_VARS: ") - 1);
			result.append(envvarsBase64Data, envvarsBase64Len);
			result.append("\r\n", 2);
			free(envvarsBase64Data);
		}

		// Add flags.
		// C = Strip 100 Continue header
		// D = Dechunk
		// B = Buffer request body
		// S = SSL

		result.append("!~FLAGS: CD", sizeof("!~FLAGS: CD") - 1);
		if (config->bufferUpload != DirConfig::DISABLED) {
			result.append("B", 1);
		}
		if (lookupEnv(r, "HTTPS") != NULL) {
			result.append("S", 1);
		}
		result.append("\r\n\r\n", 4);

		return result;
	}

	static int getsfunc_BRIGADE(char *buf, int len, void *arg) {
		apr_bucket_brigade *bb = (apr_bucket_brigade *)arg;
		const char *dst_end = buf + len - 1; /* leave room for terminating null */
		char *dst = buf;
		apr_bucket *e = APR_BRIGADE_FIRST(bb);
		apr_status_t rv;
		int done = 0;

		while ((dst < dst_end) && !done && e != APR_BRIGADE_SENTINEL(bb)
			&& !APR_BUCKET_IS_EOS(e))
		{
			const char *bucket_data;
			apr_size_t bucket_data_len;
			const char *src;
			const char *src_end;
			apr_bucket * next;

			rv = apr_bucket_read(e, &bucket_data, &bucket_data_len,
			                 APR_BLOCK_READ);
			if (rv != APR_SUCCESS || (bucket_data_len == 0)) {
				*dst = '\0';
				return APR_STATUS_IS_TIMEUP(rv) ? -1 : 0;
			}
			src = bucket_data;
			src_end = bucket_data + bucket_data_len;
			while ((src < src_end) && (dst < dst_end) && !done) {
				if (*src == '\n') {
		    		done = 1;
				}
				else if (*src != '\r') {
		    		*dst++ = *src;
				}
				src++;
			}

			if (src < src_end) {
				apr_bucket_split(e, src - bucket_data);
			}
			next = APR_BUCKET_NEXT(e);
			APR_BUCKET_REMOVE(e);
			apr_bucket_destroy(e);
			e = next;
		}
		*dst = 0;
		return done;
	}

	/**
	 * Reads the next chunk of the request body and put it into a buffer.
	 *
	 * This is like ap_get_client_block(), but can actually report errors
	 * in a sane way. ap_get_client_block() tells you that something went
	 * wrong, but not *what* went wrong.
	 *
	 * @param r The current request.
	 * @param buffer A buffer to put the read data into.
	 * @param bufsiz The size of the buffer.
	 * @return The number of bytes read, or 0 on EOF.
	 * @throws RuntimeException Something non-I/O related went wrong, e.g.
	 *                          failure to allocate memory and stuff.
	 * @throws IOException An I/O error occurred while trying to read the
	 *                     request body data.
	 */
	unsigned long readRequestBodyFromApache(request_rec *r, char *buffer, apr_size_t bufsiz) {
		apr_status_t rv;
		apr_bucket_brigade *bb;

		if (r->remaining < 0 || (!r->read_chunked && r->remaining == 0)) {
			return 0;
		}

		bb = apr_brigade_create(r->pool, r->connection->bucket_alloc);
		if (bb == NULL) {
			r->connection->keepalive = AP_CONN_CLOSE;
			throw RuntimeException("An error occurred while receiving HTTP upload data: "
				"unable to create a bucket brigade. Maybe the system doesn't have "
				"enough free memory.");
		}

		rv = ap_get_brigade(r->input_filters, bb, AP_MODE_READBYTES,
		                    APR_BLOCK_READ, bufsiz);

		/* We lose the failure code here.  This is why ap_get_client_block should
		 * not be used.
		 */
		if (rv != APR_SUCCESS) {
			/* if we actually fail here, we want to just return and
			 * stop trying to read data from the client.
			 */
			r->connection->keepalive = AP_CONN_CLOSE;
			apr_brigade_destroy(bb);

			char buf[150], *errorString, message[1024];
			errorString = apr_strerror(rv, buf, sizeof(buf));
			if (errorString != NULL) {
				snprintf(message, sizeof(message),
					"An error occurred while receiving HTTP upload data: %s (%d)",
					errorString, rv);
			} else {
				snprintf(message, sizeof(message),
					"An error occurred while receiving HTTP upload data: unknown error %d",
					rv);
			}
			message[sizeof(message) - 1] = '\0';
			throw RuntimeException(message);
		}

		/* If this fails, it means that a filter is written incorrectly and that
		 * it needs to learn how to properly handle APR_BLOCK_READ requests by
		 * returning data when requested.
		 */
		if (APR_BRIGADE_EMPTY(bb)) {
			throw RuntimeException("An error occurred while receiving HTTP upload data: "
				"the next filter in the input filter chain has "
				"a bug. Please contact the author who wrote this filter about "
				"this. This problem is not caused by Phusion Passenger.");
		}

		/* Check to see if EOS in the brigade.
		 *
		 * If so, we have to leave a nugget for the *next* readRequestBodyFromApache()
		 * call to return 0.
		 */
		if (APR_BUCKET_IS_EOS(APR_BRIGADE_LAST(bb))) {
			if (r->read_chunked) {
				r->remaining = -1;
			} else {
				r->remaining = 0;
			}
		}

		rv = apr_brigade_flatten(bb, buffer, &bufsiz);
		if (rv != APR_SUCCESS) {
			apr_brigade_destroy(bb);

			char buf[150], *errorString, message[1024];
			errorString = apr_strerror(rv, buf, sizeof(buf));
			if (errorString != NULL) {
				snprintf(message, sizeof(message),
					"An error occurred while receiving HTTP upload data: %s (%d)",
					errorString, rv);
			} else {
				snprintf(message, sizeof(message),
					"An error occurred while receiving HTTP upload data: unknown error %d",
					rv);
			}
			message[sizeof(message) - 1] = '\0';
			throw IOException(message);
		}

		/* XXX yank me? */
		r->read_length += bufsiz;

		apr_brigade_destroy(bb);
		return bufsiz;
	}

	void sendRequestBody(const FileDescriptor &fd, request_rec *r, bool chunk) {
		TRACE_POINT();
		char buf[1024 * 32];
		apr_off_t len;

		try {
			while ((len = readRequestBodyFromApache(r, buf, sizeof(buf))) > 0) {
				if (chunk) {
					const apr_off_t BUFSIZE = 2 * sizeof(apr_off_t) + 3;
					char buf[BUFSIZE];
					char *pos;
					const char *end = buf + BUFSIZE;

					pos = buf + integerToHex<apr_off_t>(len, buf);
					pos = appendData(pos, end, P_STATIC_STRING("\r\n"));
					writeExact(fd, buf, pos - buf);
				}
				writeExact(fd, buf, len);
				if (chunk) {
					writeExact(fd, "\r\n");
				}
			}
			if (chunk) {
				writeExact(fd, "0\r\n\r\n");
			}
		} catch (const SystemException &e) {
			if (e.code() == EPIPE || e.code() == ECONNRESET) {
				// The Passenger core stopped reading the body, probably
				// because the application already sent EOF.
				return;
			} else {
				throw e;
			}
		}
	}

public:
	Hooks(apr_pool_t *pconf, apr_pool_t *plog, apr_pool_t *ptemp, server_rec *s)
	    : cstat(1024),
	      agentsStarter(AS_APACHE)
	{
		serverConfig.finalize();
		Passenger::setLogLevel(serverConfig.logLevel);
		if (serverConfig.logFile != NULL) {
			int errcode;
			if (!Passenger::setLogFileWithoutRedirectingStderr(serverConfig.logFile, &errcode)) {
				fprintf(stderr,
					"ERROR: cannot open log file %s: %s (errno=%d)\n",
					serverConfig.logFile,
					strerror(errcode),
					errcode);
			}
		}
		if (serverConfig.fileDescriptorLogFile != NULL) {
			Passenger::setFileDescriptorLogFile(serverConfig.fileDescriptorLogFile);
		}
		m_hasModRewrite = UNKNOWN;
		m_hasModDir = UNKNOWN;
		m_hasModAutoIndex = UNKNOWN;
		m_hasModXsendfile = UNKNOWN;

		P_DEBUG("Initializing Phusion Passenger...");
		ap_add_version_component(pconf, SERVER_TOKEN_NAME "/" PASSENGER_VERSION);

		if (serverConfig.root == NULL) {
			throw ConfigurationException("The 'PassengerRoot' configuration option "
				"is not specified. This option is required, so please specify it. "
				"TIP: The correct value for this option was given to you by "
				"'passenger-install-apache2-module'.");
		}

		#ifdef AP_GET_SERVER_VERSION_DEPRECATED
			const char *webServerDesc = ap_get_server_description();
		#else
			const char *webServerDesc = ap_get_server_version();
		#endif

		VariantMap params;
		params
			.setPid ("web_server_control_process_pid", getpid())
			.setStrSet("web_server_config_files", getConfigFiles(s))
			.set    ("server_software", webServerDesc)
			.setBool("multi_app", true)
			.setBool("load_shell_envvars", true)
			.set    ("file_descriptor_log_file", (serverConfig.fileDescriptorLogFile == NULL)
				? "" : serverConfig.fileDescriptorLogFile)
			.set    ("data_buffer_dir", serverConfig.dataBufferDir)
			.set    ("instance_registry_dir", serverConfig.instanceRegistryDir)
			.setBool("user_switching", serverConfig.userSwitching)
			.set    ("default_user", serverConfig.defaultUser)
			.set    ("default_group", serverConfig.defaultGroup)
			.set    ("default_ruby", serverConfig.defaultRuby)
			.setInt ("max_pool_size", serverConfig.maxPoolSize)
			.setInt ("pool_idle_time", serverConfig.poolIdleTime)
			.setInt ("response_buffer_high_watermark", serverConfig.responseBufferHighWatermark)
			.setInt ("stat_throttle_rate", serverConfig.statThrottleRate)
			.set    ("analytics_log_user", serverConfig.analyticsLogUser)
			.set    ("analytics_log_group", serverConfig.analyticsLogGroup)
			.set    ("union_station_gateway_address", serverConfig.unionStationGatewayAddress)
			.setInt ("union_station_gateway_port", serverConfig.unionStationGatewayPort)
			.set    ("union_station_gateway_cert", serverConfig.unionStationGatewayCert)
			.set    ("union_station_proxy_address", serverConfig.unionStationProxyAddress)
			.setBool("turbocaching", serverConfig.turbocaching)
			.setStrSet("prestart_urls", serverConfig.prestartURLs);

		if (serverConfig.logFile != NULL) {
			params.set("log_file", serverConfig.logFile);
		} else if (s->error_fname == NULL) {
			throw ConfigurationException("Cannot initialize " PROGRAM_NAME
				" because Apache is not configured with an error log file."
				" Please either configure Apache with an error log file"
				" (with the ErrorLog directive), or configure "
				PROGRAM_NAME " with a `PassengerLogFile` directive.");
		} else if (s->error_fname[0] == '|') {
			throw ConfigurationException("Apache is configured to log to a pipe,"
				" so " SHORT_PROGRAM_NAME " cannot be initialized because it doesn't"
				" support logging to a pipe. Please configure " SHORT_PROGRAM_NAME
				" with an explicit log file using the `PassengerLogFile` directive.");
		} else if (strcmp(s->error_fname, "syslog") == 0) {
			throw ConfigurationException("Apache is configured to log to syslog,"
				" so " SHORT_PROGRAM_NAME " cannot be initialized because it doesn't"
				" support logging to syslog. Please configure " SHORT_PROGRAM_NAME
				" with an explicit log file using the `PassengerLogFile` directive.");
		} else {
			params.set("log_file", ap_server_root_relative(pconf, s->error_fname));
		}

		serverConfig.ctl.addTo(params);

		agentsStarter.start(serverConfig.root, params);
	}

	void childInit(apr_pool_t *pchild, server_rec *s) {
		agentsStarter.detach();
	}

	int prepareRequestWhenInHighPerformanceMode(request_rec *r) {
		DirConfig *config = getDirConfig(r);
		if (config->isEnabled() && config->highPerformanceMode()) {
			if (prepareRequest(r, config, r->filename, true)) {
				return OK;
			} else {
				return DECLINED;
			}
		} else {
			return DECLINED;
		}
	}

	/**
	 * This is the hook method for the map_to_storage hook. Apache's final map_to_storage hook
	 * method (defined in core.c) will do the following:
	 *
	 * If r->filename doesn't exist, then it will change the filename to the
	 * following form:
	 *
	 *     A/B
	 *
	 * A is top-most directory that exists. B is the first filename piece that
	 * normally follows A. For example, suppose that a website's DocumentRoot
	 * is /website, on server http://test.com/. Suppose that there's also a
	 * directory /website/images. No other files or directories exist in /website.
	 *
	 * If we access:                    then r->filename will be:
	 * http://test.com/foo/bar          /website/foo
	 * http://test.com/foo/bar/baz      /website/foo
	 * http://test.com/images/foo/bar   /website/images/foo
	 *
	 * We obviously don't want this to happen because it'll interfere with our page
	 * cache file search code. So here we save the original value of r->filename so
	 * that we can use it later.
	 */
	int saveOriginalFilename(request_rec *r) {
		apr_table_set(r->notes, "Phusion Passenger: original filename", r->filename);
		return DECLINED;
	}

	int prepareRequestWhenNotInHighPerformanceMode(request_rec *r) {
		DirConfig *config = getDirConfig(r);
		if (config->isEnabled()) {
			if (config->highPerformanceMode()) {
				/* Preparations have already been done in the map_to_storage hook.
				 * Prevent other modules' fixups hooks from being run.
				 */
				return OK;
			} else {
				/* core.c's map_to_storage hook will transform the filename, as
				 * described by saveOriginalFilename(). Here we restore the
				 * original filename.
				 */
				const char *filename = apr_table_get(r->notes, "Phusion Passenger: original filename");
				if (filename == NULL) {
					return DECLINED;
				} else {
					prepareRequest(r, config, filename);
					/* Always return declined in order to let other modules'
					 * hooks run, regardless of what prepareRequest()'s
					 * result is.
					 */
					return DECLINED;
				}
			}
		} else {
			return DECLINED;
		}
	}

	/**
	 * The default .htaccess provided by on Rails on Rails (that is, before version 2.1.0)
	 * has the following mod_rewrite rules in it:
	 *
	 *   RewriteEngine on
	 *   RewriteRule ^$ index.html [QSA]
	 *   RewriteRule ^([^.]+)$ $1.html [QSA]
	 *   RewriteCond %{REQUEST_FILENAME} !-f
	 *   RewriteRule ^(.*)$ dispatch.cgi [QSA,L]
	 *
	 * As a result, all requests that do not map to a filename will be redirected to
	 * dispatch.cgi (or dispatch.fcgi, if the user so specified). We don't want that
	 * to happen, so before mod_rewrite applies its rules, we save the current state.
	 * After mod_rewrite has applied its rules, undoRedirectionToDispatchCgi() will
	 * check whether mod_rewrite attempted to perform an internal redirection to
	 * dispatch.(f)cgi. If so, then it will revert the state to the way it was before
	 * mod_rewrite took place.
	 */
	int saveStateBeforeRewriteRules(request_rec *r) {
		RequestNote *note = getRequestNote(r);
		if (note != 0 && hasModRewrite()) {
			note->handlerBeforeModRewrite = r->handler;
			note->filenameBeforeModRewrite = r->filename;
		}
		return DECLINED;
	}

	int undoRedirectionToDispatchCgi(request_rec *r) {
		RequestNote *note = getRequestNote(r);
		if (note == 0 || !hasModRewrite()) {
			return DECLINED;
		}

		if (r->handler != NULL && strcmp(r->handler, "redirect-handler") == 0) {
			// Check whether r->filename looks like "redirect:.../dispatch.(f)cgi"
			size_t len = strlen(r->filename);
			// 22 == strlen("redirect:/dispatch.cgi")
			if (len >= 22 && memcmp(r->filename, "redirect:", 9) == 0
			 && (memcmp(r->filename + len - 13, "/dispatch.cgi", 13) == 0
			  || memcmp(r->filename + len - 14, "/dispatch.fcgi", 14) == 0)) {
				if (note->filenameBeforeModRewrite != NULL) {
					r->filename = note->filenameBeforeModRewrite;
					r->canonical_filename = note->filenameBeforeModRewrite;
					r->handler = note->handlerBeforeModRewrite;
				}
			}
		}
		return DECLINED;
	}

	/**
	 * mod_dir does the following:
	 * If r->filename is a directory, and the URI doesn't end with a slash,
	 * then it will redirect the browser to an URI with a slash. For example,
	 * if you go to http://foo.com/images, then it will redirect you to
	 * http://foo.com/images/.
	 *
	 * This behavior is undesired. Suppose that there is an ImagesController,
	 * and there's also a 'public/images' folder used for storing page cache
	 * files. Then we don't want mod_dir to perform the redirection.
	 *
	 * So in startBlockingModDir(), we temporarily change some fields in the
	 * request structure in order to block mod_dir. In endBlockingModDir() we
	 * revert those fields to their old value.
	 */
	int startBlockingModDir(request_rec *r) {
		RequestNote *note = getRequestNote(r);
		if (note != 0 && hasModDir()) {
			note->oldFileType = r->finfo.filetype;
			r->finfo.filetype = APR_NOFILE;
		}
		return DECLINED;
	}

	int endBlockingModDir(request_rec *r) {
		RequestNote *note = getRequestNote(r);
		if (note != 0 && hasModDir()) {
			r->finfo.filetype = note->oldFileType;
		}
		return DECLINED;
	}

	/**
	 * mod_autoindex will try to display a directory index for URIs that map to a directory.
	 * This is undesired because of page caching semantics. Suppose that a Rails application
	 * has an ImagesController which has page caching enabled, and thus also a 'public/images'
	 * directory. When the visitor visits /images we'll want the request to be forwarded to
	 * the Rails application, instead of displaying a directory index.
	 *
	 * So in this hook method, we temporarily change some fields in the request structure
	 * in order to block mod_autoindex. In endBlockingModAutoIndex(), we restore the request
	 * structure to its former state.
	 */
	int startBlockingModAutoIndex(request_rec *r) {
		RequestNote *note = getRequestNote(r);
		if (note != 0 && hasModAutoIndex()) {
			note->handlerBeforeModAutoIndex = r->handler;
			r->handler = "";
		}
		return DECLINED;
	}

	int endBlockingModAutoIndex(request_rec *r) {
		RequestNote *note = getRequestNote(r);
		if (note != 0 && hasModAutoIndex()) {
			r->handler = note->handlerBeforeModAutoIndex;
		}
		return DECLINED;
	}

	int handleRequestWhenInHighPerformanceMode(request_rec *r) {
		DirConfig *config = getDirConfig(r);
		if (config->highPerformanceMode()) {
			return handleRequest(r);
		} else {
			return DECLINED;
		}
	}

	int handleRequestWhenNotInHighPerformanceMode(request_rec *r) {
		DirConfig *config = getDirConfig(r);
		if (config->highPerformanceMode()) {
			return DECLINED;
		} else {
			return handleRequest(r);
		}
	}
};



/******************************************************************
 * Below follows lightweight C wrappers around the C++ Hook class.
 ******************************************************************/

/**
 * @ingroup Hooks
 * @{
 */

static Hooks *hooks = NULL;

static apr_status_t
destroy_hooks(void *arg) {
	try {
		this_thread::disable_interruption di;
		this_thread::disable_syscall_interruption dsi;
		P_DEBUG("Shutting down Phusion Passenger...");
		delete hooks;
		hooks = NULL;
	} catch (const thread_interrupted &) {
		// Ignore interruptions, we're shutting down anyway.
		P_TRACE(3, "A system call was interrupted during shutdown of mod_passenger.");
	} catch (const std::exception &e) {
		// Ignore other exceptions, we're shutting down anyway.
		P_TRACE(3, "Exception during shutdown of mod_passenger: " << e.what());
	}
	return APR_SUCCESS;
}

static int
init_module(apr_pool_t *pconf, apr_pool_t *plog, apr_pool_t *ptemp, server_rec *s) {
	/*
	 * HISTORICAL NOTE:
	 *
	 * The Apache initialization process has the following properties:
	 *
	 * 1. Apache on Unix calls the post_config hook twice, once before detach() and once
	 *    after. On Windows it never calls detach().
	 * 2. When Apache is compiled to use DSO modules, the modules are unloaded between the
	 *    two post_config hook calls.
	 * 3. On Unix, if the -X commandline option is given (the 'DEBUG' config is set),
	 *    detach() will not be called.
	 *
	 * Because of property #2, the post_config hook is called twice. We initially tried
	 * to avoid this with all kinds of hacks and workarounds, but none of them are
	 * universal, i.e. it works for some people but not for others. So we got rid of the
	 * hacks, and now we always initialize in the post_config hook.
	 */
	if (hooks == NULL) {
		oxt::initialize();
	} else {
		P_DEBUG("Restarting Phusion Passenger....");
		delete hooks;
		hooks = NULL;
	}
	try {
		hooks = new Hooks(pconf, plog, ptemp, s);
		apr_pool_cleanup_register(pconf, NULL,
			destroy_hooks,
			apr_pool_cleanup_null);
		return OK;

	} catch (const thread_interrupted &e) {
		P_TRACE(2, "A system call was interrupted during mod_passenger "
			"initialization. Apache might be restarting or shutting "
			"down. Backtrace:\n" << e.backtrace());
		return DECLINED;

	} catch (const thread_resource_error &e) {
		struct rlimit lim;
		string pthread_threads_max;
		int ret;

		lim.rlim_cur = 0;
		lim.rlim_max = 0;

		/* Solaris does not define the RLIMIT_NPROC limit. Setting it to infinity... */
#ifdef RLIMIT_NPROC
		getrlimit(RLIMIT_NPROC, &lim);
#else
		lim.rlim_cur = lim.rlim_max = RLIM_INFINITY;
#endif

		#ifdef PTHREAD_THREADS_MAX
			pthread_threads_max = toString(PTHREAD_THREADS_MAX);
		#else
			pthread_threads_max = "unknown";
		#endif

		ap_log_error(APLOG_MARK, APLOG_ERR, 0, s,
			"*** Passenger could not be initialize because a "
			"threading resource could not be allocated or initialized. "
			"The error message is:");
		fprintf(stderr,
			"  %s\n\n"
			"System settings:\n"
			"  RLIMIT_NPROC: soft = %d, hard = %d\n"
			"  PTHREAD_THREADS_MAX: %s\n"
			"\n",
			e.what(),
			(int) lim.rlim_cur, (int) lim.rlim_max,
			pthread_threads_max.c_str());

		fprintf(stderr, "Output of 'uname -a' follows:\n");
		fflush(stderr);
		ret = ::system("uname -a >&2");
		(void) ret; // Ignore compiler warning.

		fprintf(stderr, "\nOutput of 'ulimit -a' follows:\n");
		fflush(stderr);
		ret = ::system("ulimit -a >&2");
		(void) ret; // Ignore compiler warning.

		return DECLINED;

	} catch (const std::exception &e) {
		ap_log_error(APLOG_MARK, APLOG_ERR, 0, s,
			"*** Passenger could not be initialized because of this error: %s",
			e.what());
		hooks = NULL;
		return DECLINED;
	}
}

static void
child_init(apr_pool_t *pchild, server_rec *s) {
	if (OXT_LIKELY(hooks != NULL)) {
		hooks->childInit(pchild, s);
	}
}

#define DEFINE_REQUEST_HOOK(c_name, cpp_name)        \
	static int c_name(request_rec *r) {          \
		if (OXT_LIKELY(hooks != NULL)) {     \
			return hooks->cpp_name(r);   \
		} else {                             \
			return DECLINED;             \
		}                                    \
	}

DEFINE_REQUEST_HOOK(prepare_request_when_in_high_performance_mode, prepareRequestWhenInHighPerformanceMode)
DEFINE_REQUEST_HOOK(save_original_filename, saveOriginalFilename)
DEFINE_REQUEST_HOOK(prepare_request_when_not_in_high_performance_mode, prepareRequestWhenNotInHighPerformanceMode)
DEFINE_REQUEST_HOOK(save_state_before_rewrite_rules, saveStateBeforeRewriteRules)
DEFINE_REQUEST_HOOK(undo_redirection_to_dispatch_cgi, undoRedirectionToDispatchCgi)
DEFINE_REQUEST_HOOK(start_blocking_mod_dir, startBlockingModDir)
DEFINE_REQUEST_HOOK(end_blocking_mod_dir, endBlockingModDir)
DEFINE_REQUEST_HOOK(start_blocking_mod_autoindex, startBlockingModAutoIndex)
DEFINE_REQUEST_HOOK(end_blocking_mod_autoindex, endBlockingModAutoIndex)
DEFINE_REQUEST_HOOK(handle_request_when_in_high_performance_mode, handleRequestWhenInHighPerformanceMode)
DEFINE_REQUEST_HOOK(handle_request_when_not_in_high_performance_mode, handleRequestWhenNotInHighPerformanceMode)


/**
 * Apache hook registration function.
 */
void
passenger_register_hooks(apr_pool_t *p) {
	static const char * const rewrite_module[] = { "mod_rewrite.c", NULL };
	static const char * const dir_module[] = { "mod_dir.c", NULL };
	static const char * const autoindex_module[] = { "mod_autoindex.c", NULL };

	ap_hook_post_config(init_module, NULL, NULL, APR_HOOK_MIDDLE);
	ap_hook_child_init(child_init, NULL, NULL, APR_HOOK_MIDDLE);

	// The hooks here are defined in the order that they're called.

	ap_hook_map_to_storage(prepare_request_when_in_high_performance_mode, NULL, NULL, APR_HOOK_FIRST);
	ap_hook_map_to_storage(save_original_filename, NULL, NULL, APR_HOOK_LAST);

	ap_hook_fixups(prepare_request_when_not_in_high_performance_mode, NULL, rewrite_module, APR_HOOK_FIRST);
	ap_hook_fixups(save_state_before_rewrite_rules, NULL, rewrite_module, APR_HOOK_LAST);
	ap_hook_fixups(undo_redirection_to_dispatch_cgi, rewrite_module, NULL, APR_HOOK_FIRST);
	ap_hook_fixups(start_blocking_mod_dir, NULL, dir_module, APR_HOOK_LAST);
	ap_hook_fixups(end_blocking_mod_dir, dir_module, NULL, APR_HOOK_LAST);

	ap_hook_handler(handle_request_when_in_high_performance_mode, NULL, NULL, APR_HOOK_FIRST);
	ap_hook_handler(start_blocking_mod_autoindex, NULL, autoindex_module, APR_HOOK_LAST);
	ap_hook_handler(end_blocking_mod_autoindex, autoindex_module, NULL, APR_HOOK_FIRST);
	ap_hook_handler(handle_request_when_not_in_high_performance_mode, NULL, NULL, APR_HOOK_LAST);
}

/**
 * @}
 */

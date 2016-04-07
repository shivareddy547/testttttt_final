
//.unbind()


$(document).on('change', '#user_billable', function(event) {
    event.stopImmediatePropagation();
    // code here
    //alert("++++")
    member_id = $(this).attr("member_id");
    if($(this).val() == "1") {
        //alert("billable")
        var billable_status= 1
        $('<input>').attr({
            type: 'hidden',
            id: 'member_billable_'+member_id,
            name: 'billable',
            value: billable_status
        }).appendTo('#member-'+member_id+'-roles-form');
        $('#member-'+member_id+'-roles-form').find('[name=commit]').attr("disabled", false);
    }
    else if($(this).val() == "2")
    {

        //alert("Non billable")
        var billable_status= 2
        $('<input>').attr({
            type: 'hidden',
            id: 'member_billable_'+member_id,
            name: 'billable',
            value: billable_status
        }).appendTo('#member-'+member_id+'-roles-form');
        $('#member-'+member_id+'-roles-form').find('[name=commit]').attr("disabled", false);

    }

    else if($(this).val() == "3")
    {

        //alert("Non billable")
        var billable_status= 3
        $('<input>').attr({
            type: 'hidden',
            id: 'member_billable_'+member_id,
            name: 'billable',
            value: billable_status
        }).appendTo('#member-'+member_id+'-roles-form');
        $('#member-'+member_id+'-roles-form').find('[name=commit]').attr("disabled", false);

        $(this).parent().parent().find("#div_member_capacity_slider").slider('value', 0);
        $("#member_capacity_"+$(this).attr("member_id")).val(0)
    }

    else{
        alert("Error:Please Select Billable Or Shadow or Support")
        var billable_status= ""
        $('<input>').attr({
            type: 'hidden',
            id: 'member_billable_'+member_id,
            name: 'billable',
            value: billable_status
        }).appendTo('#member-'+member_id+'-roles-form');
        $('#member-'+member_id+'-roles-form').find('[name=commit]').attr("disabled", true);

    }

});

$(document).on('click', 'table.memberships .icon-edit', function(event) {
    event.stopImmediatePropagation();
    $(this).closest('tr').find("#user_billable").attr("disabled", true);
    var billable_status = $(this).closest('tr').find("#member_billable_status").val();
    var capacity = $(this).closest('tr').find("input#current_capacity").val();
    var member_id = $(this).closest('tr').find("#member_billable_status").attr("member_id");
    $('#member-'+member_id+'-roles-form').find('a').attr('id', 'cancel_member');
    $('#member-'+member_id+'-roles-form').find('a').attr('member_id', member_id);
//    $(this).closest('tr').find("#div_member_capacity_slider").slider('enable');
    $(this).closest('tr').find("#div_member_capacity_slider").show();

    if (billable_status == "billable")
    {
        billable_status = 1
    }
    else if(billable_status == "shadow")
    {
        billable_status = 2
    }
    else if(billable_status == "support")
    {
        billable_status = 3
    }

    $('<input>').attr({
        type: 'hidden',
        id: 'member_billable_'+member_id,
        name: 'billable',
        value: billable_status
    }).appendTo('#member-'+member_id+'-roles-form');

    $('<input>').attr({
        type: 'hidden',
        id: 'member_capacity_'+member_id,
        name: 'capacity',
        value: capacity
    }).appendTo('#member-'+member_id+'-roles-form');



});

$(document).on('click', '#cancel_member', function(event) {
    event.stopImmediatePropagation();
    var billable_status = $(this).closest('tr').find("#member_billable_status").val();
    //alert(billable_status);
    var member_id = $(this).attr("member_id");
     $(this).closest('tr').find("#user_billable").attr("disabled", true);
//    $(this).closest('tr').find("#").attr("disabled", true);
    console.log($(this).closest('tr').find("#div_member_capacity_slider"))
    $(this).closest('tr').find("#div_member_capacity_slider").slider('disable');
    return false;

});

//
//$(document).on('change', '#billable', function(event) {
//
//    //$('select').on('change', function() {
//    event.stopImmediatePropagation();
//    var other_capacity = $("form#user_new_membership").find("input#member_total_capacity").val();
//
//    if($(this).val()) {
//
//        if($(this).val() == "3") {
//            //alert("billable")
////            var other_capacity = $("form#user_new_membership").find("input#member_total_capacity").val();
//            $(this).parent().parent().find("#div_member_capacity_slider").slider('value', 0);
////            $(this).parent().parent().find("#div_member_capacity_slider").slider('value', 0);
//            $("form#user_new_membership #member_capacity").val(other_capacity)
//
//        }
//    }
//    else{
//        alert("Error:Please Select Billable Or Shadow or Support")
//
//        $(this).parent().parent().find("#div_member_capacity_slider").slider('value', other_capacity);
//        $("#user_new_membership").find('[name=commit]').attr("disabled", true);
//    }
//
//
//});

//$(function() {
//    $( "#slider" ).slider();
//});


/* Loading chart Handile bar */

$( document ).ready(function() {
    // Handler for .ready() called.

    $(".list.memberships #member_capacity").each(function() {

        var current_capacity = $(this).find("input#current_capacity").val();
        var available_capacity = $(this).find("input#available_capacity").val();
        var other_capacity = $(this).find("input#other_capacity").val();
        var element = $(this);
        var member_id= $(this).find("input#member_id").val();
        /* slider tooltip */
        var tooltip = $('<div id="tooltip" />').css({
            position: 'absolute',
            top: -25,
            left: -10
        }).hide();

        /* Google chart options */
        var options = {
            width: 200,
            height: 150,
            backgroundColor: "#ffffdd",
            pieHole: 0.4,
            pieSliceText: "value",
            text: "value",
            tooltip: { isHtml: true },
            tooltip: {text: "percentage"},
            pieSliceTextStyle: {
                color: 'black',
                bold: true,
                italic: true,
                alignment: "center"
            },
            colors: ['#FF9933', '#E82D2D', '#006600'],
            legend: {
                alignment: 'center', textStyle: {color: 'blue', fontSize: 8}
            }
        };

        $(this).find("#div_member_capacity_slider").slider({
            range: "min",
            step: 5,
            value: current_capacity,
            min: 0,
            max: 100,
            slide: function( event, ui ) {

                var billable_value = $('#member-'+member_id+'-roles-form').closest('tr').find("#user_billable").val();

                if(billable_value == 2 || billable_value == 1)
                {
                    if(ui.value < 5 )
                    {
                        return false;
                    }

                }
                else{
                    return false
                }

                if(ui.value > (100-other_capacity) )
                {
                    return false;
                }
                $(element).find("span#selected_capacity" ).text( "Selected: " + ui.value+"%" );
                $(element).find("input#selected_capacity" ).val(ui.value);
//                $(element).find("#tooltip").text($(this).parent().find(".ui-slider-range").attr("style").split(":")[1].split("%")[0]);
                $(element).find("#tooltip").text(ui.value);
                $('#member-'+member_id+'-roles-form').find('#member_capacity_'+member_id).val(ui.value);
                var current_capacity=ui.value;
                var available_capacity= (100-(parseInt(current_capacity)+parseInt(other_capacity)));
                var data = google.visualization.arrayToDataTable([
                    ['Type', 'Value'],
                    ['Available',     parseInt(available_capacity)],
                    ['Other',     parseInt(other_capacity)],
                    ['Assigned',     parseInt(current_capacity)],
                ]);
                var chart = new google.visualization.PieChart($("#capacity_chart_"+member_id)[0]);
                chart.draw(data, options);

            },
            change: function(event, ui) {}
        }).find(".ui-slider-handle").append(tooltip).hover(function() {
//                $(this).parent().find(".ui-slider-range").width();
                tooltip.show();
//                console.log($(this).parent().find(".ui-slider-range").width());

                $(this).find("#tooltip").text($(this).parent().find(".ui-slider-range").attr("style").split(":")[1].split("%")[0]);
            }, function() {
                tooltip.hide();
            }
        );
        var data = google.visualization.arrayToDataTable([
            ['Type', 'Value'],
            ['Available',     parseInt(available_capacity)],
            ['Other',     parseInt(other_capacity)],
            ['Assigned',     parseInt(current_capacity)],
        ]);
        /* Google chart draw */
        if(member_id) {
            var chart = new google.visualization.PieChart($("#capacity_chart_" + member_id)[0]);
            chart.draw(data, options);
            google.visualization.events.addListener(chart, 'click', function(e) {
                var match_sting = e.targetID.match(/slice#/g);
                if(match_sting)
                {
                    var position = e.targetID.split("#").last
                }
                if(e.targetID.split("#")[1]==1)
                {
                    var position = e.targetID.split("#").last
                    $.ajax({
                        url: "/employee_info/get_capacity_details_of_other_project", // Route to the Script Controller method
                        type: "POST",
                        dataType: "json",
                        data: {member_id:member_id},
                        // This goes to Controller in params hash, i.e. params[:file_name]
                        complete: function () {
                        },
                        success: function (data) {
                            if($("#member-"+data.member_id+" td").last().find("#OtherCapacitypopupWindow").dialog( "isOpen" ))
                            {
                                $("#member-"+data.member_id+" td").last().find("#OtherCapacitypopupWindow").dialog( "close" );
                                $("#member-"+data.member_id+" td").last().find("#OtherCapacitypopupWindow").remove();
                            }
                            $("#member-"+data.member_id+" td").last().append(data.CapacityDetailsPartial);

                            $( "#OtherCapacitypopupWindow" ).dialog({
                                resizable: false,
                                width:600,

                                modal: true,
                                buttons: {

                                    Close: function() {
                                        $( this ).dialog( "close" );
                                    }
                                }
                            });
                        }

                    });
                }

            });
            google.visualization.events.addListener(chart, 'onmouseover', barMouseOver);
            google.visualization.events.addListener(chart, 'onmouseout', barMouseOut);

        }

        function barMouseOver(e) {
            if(e.row == 1)
            {
                $("#capacity_chart_"+member_id).css('cursor','pointer');
            }
        }

        function barMouseOut(e) {
            if(e.row == 1)
            {
                $("#capacity_chart_"+member_id).css('cursor','');
            }

        }
        $(element).find("span#selected_capacity" ).text( "Selected" + $(element).find("#div_member_capacity_slider").slider( "value" )+"%" );
        $(element).find("#div_member_capacity_slider").slider('disable');

    });


});

//$( document ).ready(function() {
//    // Handler for .ready() called.
//
//    $(".list.memberships #member_capacity").each(function() {
//
//        var current_capacity = $(this).find("input#current_capacity").val();
//        var available_capacity = $(this).find("input#available_capacity").val();
//        var other_capacity = $(this).find("input#other_capacity").val();
//        var element = $(this);
//        var member_id= $(this).find("input#member_id").val();
///* slider tooltip */
//        var tooltip = $('<div id="tooltip" />').css({
//            position: 'absolute',
//            top: -25,
//            left: -10
//        }).hide();
//
///* Google chart options */
//        var options = {
//            width: 200,
//            height: 200,
//            backgroundColor: "#ffffdd",
//            pieHole: 0.4,
//            pieSliceText: "value",
//            text: "value",
//            tooltip: {text: "percentage"},
//            pieSliceTextStyle: {
//                color: 'black',
//                bold: true,
//                italic: true,
//                alignment: "center"
//                    },
//            colors: ['#FF9933', '#E82D2D', '#006600'],
//            legend: {
//                alignment: 'center', textStyle: {color: 'blue', fontSize: 8}
//            }
//        };
//
//        $(this).find("#div_member_capacity_slider").slider({
//            range: "min",
//            step: 05,
//            value: current_capacity,
//            min: 0,
//            max: 100,
//            slide: function( event, ui ) {
//
//                tooltip.text(ui.value);
//                if(ui.value > (100-other_capacity) )
//                {
//                    return false;
//                }
////                if(ui.value == 0)
////                {
//////                    console.log("777777777777777777777777777777")
////                    $("form#user_new_membership select#billable").attr("disabled", true);
////                    $("form#user_new_membership select#billable").val("Non Billable");
////                }
////                else
////                {
////                    $("form#user_new_membership select#billable").attr("disabled", false);
////                }
//                if(ui.value == 0)
//                {
//                    $('#member-'+member_id+'-roles-form').closest('tr').find("#user_billable").attr("disabled", true);
//                    $('#member-'+member_id+'-roles-form').closest('tr').find("#user_billable").val("Non Billable");
//                    $('#member-'+member_id+'-roles-form').closest('tr').find("#billable").val("false");
//                    $('#member-'+member_id+' '+ '#member_billable_status').val("false");
//                }
//                else
//                {
//                    $('#member-'+member_id+'-roles-form').closest('tr').find("#user_billable").attr("disabled", false);
//                    billable_value = $('#member-'+member_id+' '+ '#user_billable').val();
////                   console.log('#member-'+member_id+' '+ '#member_billable_status')
//                    console.log(billable_value)
//                    if(billable_value=="Billable") {
//                        $('#member-' + member_id + '-roles-form').closest('tr').find("#user_billable").val("Billable");
//                        $('#member-'+member_id+' '+ '#member_billable_status').val(true);
//                    }
//                    else if(billable_value=="false")
//                    {
//                        $('#member-' + member_id + '-roles-form').closest('tr').find("#user_billable").val("Non Billable");
//                        $('#member-'+member_id+' '+ '#member_billable_status').val(false);
//                    }
//                }
//
//
//                if(ui.value == 0)
//                {
//                    $('#member-'+member_id+'-roles-form').closest('tr').find("#user_billable").attr("disabled", true);
//                    $('#member-'+member_id+'-roles-form').closest('tr').find("#user_billable").val("Non Billable");
//                    $('#member-'+member_id+'-roles-form').closest('tr').find("#billable").val("false");
//                    $('#member-'+member_id+' '+ '#member_billable_status').val("false");
//                }
//                else
//                {
//                    $('#member-'+member_id+'-roles-form').closest('tr').find("#user_billable").attr("disabled", false);
//                    billable_value = $('#member-'+member_id+' '+ '#member_billable_status').val();
//                    console.log('#member-'+member_id+' '+ '#member_billable_status')
//                    console.log(billable_value)
//                    if(billable_value=="true") {
//                        $('#member-' + member_id + '-roles-form').closest('tr').find("#user_billable").val("Billable");
//                    }
//                    else if(billable_value=="false")
//                    {
//                        $('#member-' + member_id + '-roles-form').closest('tr').find("#user_billable").val("Non Billable");
//                    }
//                }
//
//                $(element).find("span#selected_capacity" ).text( "Selected: " + ui.value+"%" );
//                $(element).find("input#selected_capacity" ).val(ui.value);
//                $('#member-'+member_id+'-roles-form').find('#member_capacity_'+member_id).val(ui.value);
//                var current_capacity=ui.value;
//                var available_capacity= (100-(parseInt(current_capacity)+parseInt(other_capacity)));
//                var data = google.visualization.arrayToDataTable([
//                    ['Type', 'Value'],
//                    ['Available',     parseInt(available_capacity)],
//                    ['Other',     parseInt(other_capacity)],
//                    ['Assigned',     parseInt(current_capacity)],
//                ]);
//                var chart = new google.visualization.PieChart($("#capacity_chart_"+member_id)[0]);
//                chart.draw(data, options);
//
//            },
//            change: function(event, ui) {}
//        }).find(".ui-slider-handle").append(tooltip).hover(function() {
//                tooltip.show();
//            }, function() {
//                tooltip.hide();
//            }
//        );
//        var data = google.visualization.arrayToDataTable([
//            ['Type', 'Value'],
//            ['Available',     parseInt(available_capacity)],
//            ['Other',     parseInt(other_capacity)],
//            ['Assigned',     parseInt(current_capacity)],
//        ]);
///* Google chart draw */
//        if(member_id) {
//            var chart = new google.visualization.PieChart($("#capacity_chart_" + member_id)[0]);
//            chart.draw(data, options);
//            google.visualization.events.addListener(chart, 'click', function(e) {
//                var match_sting = e.targetID.match(/slice#/g);
//                if(match_sting)
//                {
//                    var position = e.targetID.split("#").last
//                }
//                 if(e.targetID.split("#")[1]==1)
//                 {
//                    var position = e.targetID.split("#").last
//                    $.ajax({
//                         url: "/employee_info/get_capacity_details_of_other_project", // Route to the Script Controller method
//                         type: "POST",
//                         dataType: "json",
//                         data: {member_id:member_id},
//                         // This goes to Controller in params hash, i.e. params[:file_name]
//                         complete: function () {
//                         },
//                         success: function (data) {
//                             if($("#member-"+data.member_id+" td").last().find("#OtherCapacitypopupWindow").dialog( "isOpen" ))
//                                {
//                                    $("#member-"+data.member_id+" td").last().find("#OtherCapacitypopupWindow").dialog( "close" );
//                                    $("#member-"+data.member_id+" td").last().find("#OtherCapacitypopupWindow").remove();
//                                }
//                                 $("#member-"+data.member_id+" td").last().append(data.CapacityDetailsPartial);
//                             $( "#OtherCapacitypopupWindow" ).dialog({
//                                 resizable: false,
//                                 width:600,
//
//                                 modal: true,
//                                 buttons: {
//
//                                     Close: function() {
//                                         $( this ).dialog( "close" );
//                                     }
//                                 }
//                             });
//                         }
//
//                     });
//                 }
//
//           });
//            google.visualization.events.addListener(chart, 'onmouseover', barMouseOver);
//            google.visualization.events.addListener(chart, 'onmouseout', barMouseOut);
//
//        }
//
//        function barMouseOver(e) {
//            if(e.row == 1)
//            {
//                $("#capacity_chart_"+member_id).css('cursor','pointer');
//            }
//        }
//
//        function barMouseOut(e) {
//            if(e.row == 1)
//            {
//                $("#capacity_chart_"+member_id).css('cursor','');
//            }
//
//        }
//        $(element).find("span#selected_capacity" ).text( "Selected" + $(element).find("#div_member_capacity_slider").slider( "value" )+"%" );
//        $(element).find("#div_member_capacity_slider").slider('disable');
//
//    });
//
//
//});


/* membership checkbox */



$( document ).ready(function() {
    var tooltip = $('<div id="tooltip" />').css({
        position: 'absolute',
        top: -25,
        left: -10
    }).hide();

//    var current_capacity = $("form#user_new_membership").find("input#current_capacity").val();
    var other_capacity = $("form#user_new_membership").find("input#member_total_capacity").val();
    var available_capacity = $("form#user_new_membership").find("input#available_capacity").val();

    $("form#user_new_membership #div_member_capacity_slider").slider({
        range: "min",
        step: 05,
        value: other_capacity,
        min: 0,
        max: 100,
        slide: function (event, ui) {
            tooltip.text(ui.value);
            $(this).find("input#member_capacity" ).val(ui.value);
//            if(ui.value < other_capacity )
//            {
//                return false;
//            }

            var other_capacity = $("form#user_new_membership").find("input#member_total_capacity").val();
            var available_capacity = $("form#user_new_membership").find("input#available_capacity").val();

            $(this).find("#tooltip").text($(this).parent().find(".ui-slider-range").attr("style").split(":")[1].split("%")[0]);
            $(this).find("input#member_capacity" ).val(ui.value);
//                $("form#new_membership #member_capacity").val(ui.value);
            var billable_value = $('form#user_new_membership select#billable').val();
            if(billable_value == 2 || billable_value == 1)
            {
                if(ui.value < other_capacity )
                {
                    return false;
                }

            }
            else{
                $("form#user_new_membership #member_capacity").val(other_capacity)
                return false
//                console.log($("form#user_new_membership #member_capacity"))


            }
            $("form#user_new_membership #member_capacity").val($(this).parent().find(".ui-slider-range").attr("style").split(":")[1].split("%")[0])









//            if(ui.value == 0)
//            {
//                $("form#user_new_membership select#billable").val("Non Billable");
//                $("form#user_new_membership select#billable").attr("disabled", true);
//                var billable_status= false
//                $('<input>').attr({
//                    type: 'hidden',
//                    id: 'billable',
//                    name: 'billable',
//                    value: billable_status
//                }).appendTo('#user_new_membership .capacity_slider_inline');
//           }
//            else
//            {
//                $("form#user_new_membership select#billable").attr("disabled", false);
//            }
//


            var current_selected_capacity=($(this).parent().find(".ui-slider-range").attr("style").split(":")[1].split("%")[0]-other_capacity);
//            $("form#user_new_membership #member_capacity").val(ui.value);
            $("form#user_new_membership #capacity").val(current_selected_capacity);

        },
        change: function (event, ui) {
        }
    }).find(".ui-slider-handle").append(tooltip).hover(function () {
            tooltip.show();
            $(this).find("#tooltip").text($(this).parent().find(".ui-slider-range").attr("style").split(":")[1].split("%")[0]);

        }, function () {
            tooltip.hide();
        }
    );
});


$( document ).ready(function() {
    // GET CO DO ROle

    var co_do_role = $("#get_co_do_role").val();
    if(co_do_role=="false")
    {
        $("#tab-content-members").hide();
        $(".buttons").hide();
    }

    $("form#user_new_membership #div_member_capacity_slider").slider('disable');
// Hiding the roles

    $("input[name='membership[role_ids][]']").each( function () {

        console.log($("#get_internal_role").val())

        if($("#get_internal_role").val() && $.inArray( parseInt($(this).val()), $("#get_internal_role").val().split(',').map(Number) ) == -1 )
        {
//            $(this).prop("disabled", true);
//            $(this).parent().hide();
            $(this).hide();
        }
        else
        {
//            $(this).parent().hide();
            $(this).prop("disabled", false);
        }

    });

});

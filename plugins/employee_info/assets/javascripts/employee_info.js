
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
       $("#member_capacity_"+$(this).attr("member_id")).val(0);
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

$(document).on('click', 'table.members .icon-edit', function(event) {
    event.stopImmediatePropagation();
    $(this).closest('tr').find("#user_billable").attr("disabled", false);
    var billable_status = $(this).closest('tr').find("#member_billable_status").val();
    var capacity = $(this).closest('tr').find("input#current_capacity").val();
    var member_id = $(this).closest('tr').find("#member_billable_status").attr("member_id");
    $('#member-'+member_id+'-roles-form').find('a').attr('id', 'cancel_member');
    $('#member-'+member_id+'-roles-form').find('a').attr('member_id', member_id);
    $(this).closest('tr').find("#div_member_capacity_slider").slider('enable');
    $(this).closest('tr').find("#div_member_capacity_slider").show();
console.log(billable_status)

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
    $(this).closest('tr').find("#div_member_capacity_slider").hide();
    return false;

});

$(document).on('change', 'form#new_membership #billable', function(event) {

    //$('select').on('change', function() {
    event.stopImmediatePropagation();

    if($(this).val()) {

        if($(this).val() == "3") {
            //alert("billable")
            $(this).parent().parent().find("#div_member_capacity_slider").slider('value', 0);
//            $(this).parent().parent().find("#div_member_capacity_slider").slider('value', 0);
            $("form#new_membership #member_capacity").val(0)
            $("form#new_membership").find('[name=commit]').attr("disabled", false);

        }
    }
    else{
        alert("Error:Please Select Billable Or Shadow or Support")
        $(this).parent().parent().find("#div_member_capacity_slider").slider('value', 0);
        $("form#new_membership").find('[name=commit]').attr("disabled", false);
    }


});



$( document ).ready(function() {
    // Handler for .ready() called.

    $(".list.members #member_capacity").each(function() {

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


/* membership checkbox */

$(document).on('click', 'input#member_ship_check', function() {
    var searchIDs = $("input:checkbox:checked").map(function(){
        return $(this).attr("member_available");
    }).get(); // <----
    var searchValues = $("input:checkbox:checked").map(function(){
        return $(this).attr("member_available_value");
    }).get();

    var uniq_result=unique(searchIDs)


    if(searchIDs.length)
    {
        var tooltip = $('<div id="tooltip" />').css({
            position: 'absolute',
            top: -25,
            left: -10
        }).hide();
//        $(this).attr("member_available");


        if(searchValues.sort(function(a, b){return a-b})[0])
        {
            var member_available_value = searchValues.sort(function(a, b){return a-b})[0]
        }
        else{
            var member_available_value = $(this).attr("member_available_value");
        }


        $("form#new_membership #member_capacity").val(member_available_value);
        if(member_available_value > 0)
        {
            $("form#new_membership select#billable").attr("disabled", false);
        }


        var billable_value = $('form#new_membership select#billable').val();
        if(billable_value == 3)
        {
            $("form#new_membership #div_member_capacity_slider").slider('value', 0);
//            $(this).parent().parent().find("#div_member_capacity_slider").slider('value', 0);
             member_available_value = 0;
            $("form#new_membership #member_capacity").val(0)

        }

        $("form#new_membership #div_member_capacity_slider").slider({
            range: "min",
            step: 5,
            value: member_available_value,
            min: 0,
            max: 100,
            slide: function (event, ui) {
//                $(this).find("#tooltip").text($(this).parent().find(".ui-slider-range").attr("style").split(":")[1].split("%")[0]);
                $(this).find("#tooltip").text(ui.value);
                $(this).find("input#member_capacity" ).val(ui.value);
//                $("form#new_membership #member_capacity").val(ui.value);
                var billable_value = $('form#new_membership select#billable').val();
                if(billable_value == 2 || billable_value == 1)
                {
                    if(ui.value < 5 )
                    {
                        return false;
                    }

                }
                else{
                    return false
                    console.log($("form#new_membership #member_capacity"))
                    $("form#new_membership #member_capacity").val(0)

                }
                $("form#new_membership #member_capacity").val($(this).parent().find(".ui-slider-range").attr("style").split(":")[1].split("%")[0])

//                $(element).find("#tooltip").text($(this).parent().find(".ui-slider-range").attr("style").split(":")[1].split("%")[0]);

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
    }
    else{

        if(searchValues.length == 0)
        {


        var member_available_value = 0;
        $("form#new_membership #div_member_capacity_slider").slider({
            range: "min",
            step: 5,
            value: member_available_value,
            min: 0,
            max: 100,
            slide: function (event, ui) {
                $(this).find("#tooltip").text(ui.value);
                $(this).find("input#member_capacity" ).val(ui.value);
//                $("form#new_membership #member_capacity").val(ui.value);
                var billable_value = $('form#new_membership select#billable').val();
                if(billable_value == 2 || billable_value == 1)
                {
                    if(ui.value < 5 )
                    {
                        return false;
                    }

                }
                else{
                    return false
                    console.log($("form#new_membership #member_capacity"))
                    $("form#new_membership #member_capacity").val(0)

                }
                $("form#new_membership #member_capacity").val($(this).parent().find(".ui-slider-range").attr("style").split(":")[1].split("%")[0])

//                $(element).find("#tooltip").text($(this).parent().find(".ui-slider-range").attr("style").split(":")[1].split("%")[0]);

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
        }
    }
    var member_available_value = $(this).attr("member_available_value");
    var available_value = $("form#new_membership #member_capacity").val();


    if((parseInt(member_available_value) < parseInt(available_value)) || parseInt(member_available_value) <=0)
    {
         $(this).prop('checked', false);
        var billable_value = $('form#new_membership select#billable').val();
        if(billable_value != 3 )
        {
            $(this).prop('checked', false);

        }


    }

    if(uniq_result.count > 1)
    {
        alert("Error:Please Select available members")
        $("#new_membership").find('[name=commit]').attr("disabled", true);
    }



});
function unique(list) {
    var result = [];
    $.each(list, function(i, e) {
        if ($.inArray(e, result) == -1) result.push(e);
    });
    return result;
}



$( document ).ready(function() {
    var tooltip = $('<div id="tooltip" />').css({
        position: 'absolute',
        top: -25,
        left: -10
    }).hide();

    $("form#new_membership #div_member_capacity_slider").slider({
        range: "min",
        step: 5,
        value: 0,
        min: 0,
        max: 100,
        slide: function (event, ui) {


            $(this).find("#tooltip").text(ui.value);
            $(this).find("input#member_capacity" ).val(ui.value);
            $("form#new_membership #member_capacity").val(ui.value);

            var billable_value = $('form#new_membership select#billable').val();

            if(billable_value == 2 || billable_value == 1)
            {
                if(ui.value < 5 )
                {
                    return false;
                }

            }
            else{

                $(element).parent().parent().find("#div_member_capacity_slider").slider('value', 0);
                $("form#new_membership #member_capacity").val(0)
//            $(this).parent().parent().find("#div_member_capacity_slider").slider('value', 0);
//                $("form#new_membership #member_capacity").val(0)
                return false
            }
//            $(this).find("input#member_capacity" ).val(ui.value);
//            $("form#new_membership #member_capacity").val(ui.value);

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
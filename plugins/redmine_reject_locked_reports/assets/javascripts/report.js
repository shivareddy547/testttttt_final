$(function() {

$( "#reject_report" ).click(function() {
    $( "#reject_report").addClass( "selected" );
    $( "#unlock_report").removeClass( "selected" );
    $( "#rejections_report").show();
    $( "#unlocks_report").hide();

});
$( "#unlock_report" ).click(function() {
    $( "#unlock_report").addClass( "selected" );
    $( "#reject_report").removeClass( "selected" );
    $( "#rejections_report").hide();
    $( "#unlocks_report").show();

});



    $( "#datepicker_reject_from" ).click(function() {
        $( "#datepicker_reject_from").datepicker();
        $("#datepicker_reject_from").datepicker("show");
    });
    $( "#datepicker_reject_to" ).click(function() {
        $( "#datepicker_reject_to" ).datepicker();
        $("#datepicker_reject_to").datepicker("show");
    });

    $( "#datepicker_unlock_from" ).click(function() {
        $( "#datepicker_unlock_from").datepicker();
        $("#datepicker_unlock_from").datepicker("show");
    });
    $( "#datepicker_unlock_to" ).click(function() {
        $( "#datepicker_unlock_to" ).datepicker();
        $("#datepicker_unlock_to").datepicker("show");
    });


});


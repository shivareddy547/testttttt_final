

$(document).on('click', '#tab-members', function() {
//    alert("dsfsdfsfsfs")
    var get_role = $("#get_role").val();

if(get_role == "no"){
//    $(".splitcontentleft td.buttons").css("display","none");
//    $(".splitcontentright").css("display","none");

}
    else
{

    $("form.new_membership select").val(3);
    $("form.new_membership select").attr("disabled", true);
}




});
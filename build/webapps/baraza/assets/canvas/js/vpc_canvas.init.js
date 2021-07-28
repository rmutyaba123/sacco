function assignIDSegment(segment) {

    console.log("To assignIDSegment : " + segment);

    if (segment == "products-services") {
        return ProductsServices;
    } else if (segment == "gain-creators") {
        return GainCreators;
    } else if (segment == "pain-relievers") {
        return PainRelievers;
    } else if (segment == "gains") {
        return Gains;
    } else if (segment == "pains") {
        return customerRelationships;
    } else if (segment == "customer-jobs") {
        return customerJobs;
    } else {
        return "None";
    }
}

function getNoteID(droppedElId){
    var noteID = droppedElId.split("_");

    return noteID[1];
}

dragula([
    document.getElementById("products-services"),
    document.getElementById("gain-creators"),
    document.getElementById("pain-relievers"),
    document.getElementById("gains"),
    document.getElementById("pains"),
    document.getElementById("customer-jobs")
]).on('drop', function (el) {
    var parentElId = $(el).parent().attr('id');
    var droppedElIndex = $(el).index();
    var droppedElId = $(el).attr('id');
    var noteID = getNoteID(droppedElId);
    //get the id with the related canvas segment
    var droppedElIDSegment = assignIDSegment(parentElId);

    // console.log("parentElId : " + parentElId + " droppedElIndex : " + droppedElIndex + " droppedElId : " + droppedElId);
    
    var jsonData = { 
        note_segment: droppedElIDSegment,
        note_id:  noteID  
    };

    console.log("JSON SENT : " + JSON.stringify(jsonData));
    var postDragNoteURL = 'canvas?fnct=moveVpcNote';

     $.ajax({
        type: 'POST',
        url: postDragNoteURL,
        data: jsonData,
        dataType: 'json',
        beforeSend: function () {
    
        },
        success: function (data) {

        },
        error: function (data) {

        }
    });

});


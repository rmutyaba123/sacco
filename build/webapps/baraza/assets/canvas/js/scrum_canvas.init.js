function assignIDSegment(segment) {

    // console.log("To assignIDSegment : " + segment);

    if (segment == "product_backlog") {
        return productBacklog;
    } else if (segment == "sprint_backlog") {
        return sprintBacklog;
    } else if (segment == "to_do") {
        return toDo;
    } else if (segment == "in_progress") {
        return inProgress;
    } else if (segment == "review") {
        return review;
    } else if (segment == "done") {
        return done;
    } else if (segment == "impediments") {
        return impediments;
    } else {
        return "None";
    }
}

function getNoteID(droppedElId) {
    var noteID = droppedElId.split("_");

    return noteID[1];
}

dragula([
    document.getElementById("product_backlog"),
    document.getElementById("sprint_backlog"),
    document.getElementById("to_do"),
    document.getElementById("in_progress"),
    document.getElementById("review"),
    document.getElementById("done"),
    document.getElementById("impediments")
]).on('drop', function(el) {
    var parentElId = $(el).parent().attr('id');
    var droppedElIndex = $(el).index();
    var droppedElId = $(el).attr('id');
    var noteID = getNoteID(droppedElId);
    //get the id with the related canvas segment
    var droppedElIDSegment = assignIDSegment(parentElId);

    // // console.log("parentElId : " + parentElId + " droppedElIndex : " + droppedElIndex + " droppedElId : " + droppedElId);

    var jsonData = {
        note_segment: droppedElIDSegment,
        note_id: noteID
    };

    // // console.log("JSON SENT : " + JSON.stringify(jsonData));

    var postDragNoteURL = 'canvas?fnct=moveScrumNote';

    $.ajax({
        type: 'POST',
        url: postDragNoteURL,
        data: jsonData,
        dataType: 'json',
        beforeSend: function() {

        },
        success: function(data) {

        },
        error: function(data) {

        }
    });

});
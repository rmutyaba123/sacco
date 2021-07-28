var vpcApi = function () {

    // Color Constants
    const anColor = "an";
    const gnColor = "gn";
    const ynColor = "yn";
    const rnColor = "rn";
    const enColor = "en";

    var domainUrl = 'http://localhost:3001/api';

    // addNote
    // editNote
    // moveNote
    // delNote
    // getNotes
    var postAddNoteURL = 'canvas?fnct=addVpcNote';
    var postEditNoteURL = 'canvas?fnct=editVpcNote';
    var postDeleteNoteURL = 'canvas?fnct=delVpcNote';

    var addCardModal = $("#addCardModal");
    var editCardModal = $("#editCardModal");

    // Form Create
    var frmNote = $("#frmNote");
    var frmEditNote = $("#frmEditNote");
    var btnCreateNote = $("#frmNote .btn-create");
    var btnEditNote = $("#frmEditNote .btn-edit");

    // Deletes The <p> tags
    function sanitizeSummerNote(note_content) {

        while (note_content.startsWith('<p>')) {
            note_content = note_content.replace('<p>', '')
        }

        while (note_content.endsWith('</p>')) {
            note_content = note_content.replace(new RegExp('</p>'), '')
        }

        return note_content;
    }

    /**
     * Post New Note
     */
    var handleAddNote = function () {
        console.log("handleAddVpcNote");
        $("#add-error-bag").hide();

        btnCreateNote.on('click', function () {
            var json = frmNote.serializeArray();
            var jsonData = {};

            var note_content = $("#note_content").val();
            var note_additional_details = $("#note_additional_details").val();

            note_content = sanitizeSummerNote(note_content);
            note_additional_details = sanitizeSummerNote(note_additional_details);

            $.each(json, function (i, field) {
                jsonData[field.name] = field.value;
            });

            jsonData["note_content"] = note_content;
            jsonData["note_additional_details"] = note_additional_details;

            console.log("JSON SENT => " + JSON.stringify(jsonData));

            var msgHTML = "";

            if (validateNoteContent() != "") {
                msgHTML = '<div class="alert alert-danger" role="alert">'
                    + validateNoteContent()
                    + '</div>';

                $('#msgAlert').html(msgHTML);
            } else {

                $.ajaxSetup({
                    headers: {
                        'X-CSRF-TOKEN': $('meta[name="csrf-token"]').attr('content')
                    }
                });
                // data:  JSON.stringify(jsonData),
                $.ajax({
                    type: 'POST',
                    url: postAddNoteURL,
                    data: jsonData,
                    dataType: 'json',
                    beforeSend: function () {//calls the loader id tag
                        $("#frmNote .close").click();
                        $("#loader").show();
                    },
                    success: function (data) {
                        console.log("Success +++> ");
                        console.log(data);

                        assignNotes(data.notes);

                        msgHTML = '<div class="alert alert-primary" role="alert">'
                            + 'Record Added Successfuly '
                            + '</div>';

                        $('#msgAlert').html(msgHTML);

                        frmNote.trigger("reset");
                        $("#frmNote .close").click();
                        window.location.reload();
                    },
                    error: function (data) {

                        msgHTML = '<div class="alert alert-danger" role="alert">'
                            + 'Oops! An Error Occured'
                            + '</div>';

                        $('#msgAlert').html(msgHTML);
                        // Show modal to display error showed
                        addCardModal.modal('show');
                    }
                });
            }

        });
    };

    /**
     * Post Edit Note
     */
    var handleEditNote = function () {
        console.log("handleEditVpcNote");
        $("#add-error-bag").hide();

        btnEditNote.on('click', function () {
            var json = frmEditNote.serializeArray();
            var jsonData = {};

            var note_content = $("#note_content_edit").val();
            var note_additional_details = $("#note_additional_details_edit").val();

            console.log("note_content EDIT" + note_content);

            note_content = sanitizeSummerNote(note_content);
            note_additional_details = sanitizeSummerNote(note_additional_details);

            $.each(json, function (i, field) {
                jsonData[field.name] = field.value;
            });

            console.log("JSON Before => " + JSON.stringify(jsonData));

            jsonData["note_content"] = note_content;
            jsonData["note_additional_details"] = note_additional_details;

            console.log("JSON SENT => " + JSON.stringify(jsonData));

            var msgHTML = "";

            // data:  JSON.stringify(jsonData),
            $.ajax({
                type: 'POST',
                url: postEditNoteURL,
                data: jsonData,
                dataType: 'json',
                beforeSend: function () {//calls the loader id tag
                    $("#frmEditNote .close").click();
                    $("#loader").show();
                },
                success: function (data) {
                    console.log("Success +++> ");
                    console.log(data);

                    assignNotes(data.notes);

                    msgHTML = '<div class="alert alert-primary" role="alert">'
                        + 'Note Edited Successfuly '
                        + '</div>';

                    $('#msgAlert').html(msgHTML);

                    frmEditNote.trigger("reset");
                    $("#frmEditNote .close").click();
                    window.location.reload();
                },
                error: function (data) {

                    msgHTML = '<div class="alert alert-danger" role="alert">'
                        + 'Oops! An Error Occured'
                        + '</div>';

                    $('#msgAlert').html(msgHTML);
                    // Show modal to display error showed
                    editCardModal.modal('show');
                }
            });

        });
    };

    /**
     * Get All Notes
     */
    var handleFetchNote = function () {
        console.log("handleFetchVpcNote");

        var sectionSegment = ''

        $.post('canvas?fnct=getVpcNotes', {}, function (mData) {
            console.log(mData);
            var data = mData.notes;

            // Assignes notes to the right partition
            assignNotes(data);
        });
    };

    return {
        //main function to initiate the theme
        init: function (Args) {
            args = Args;

            handleAddNote();
            handleEditNote();
            handleFetchNote();
        }
    }

}();

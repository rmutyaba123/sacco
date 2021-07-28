var bmcWizardApi = function () {

    var domainUrl = 'http://localhost:3001/api';

    // addNote
    // getNotes
    var postProgressURL = 'canvas?fnct=updateBMCProgress';
    var postAddNoteURL = 'canvas?fnct=addBmcNote';

    var allNotes = $("#m_form");

    var handleAddNote = function () {
        console.log("handleAddBMCNote");

        $(".saveBMC").on('click', function () {
            let notesData = parseNotes();
            
            for(let noteData of notesData) {
                var jsonData = noteData;

                //console.log("JSON SENT => " + JSON.stringify(jsonData));

                var msgHTML = "";

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
                    success: function (data) {
                        //console.log("Success +++> ");
                        //console.log(data);

                        msgHTML = '<div class="alert alert-primary" role="alert">'
                            + 'Record Added Successfuly '
                            + '</div>';
                    },
                    error: function (data) {

                        msgHTML = '<div class="alert alert-danger" role="alert">'
                            + 'Oops! An Error Occured'
                            + '</div>';
                    }
                });

            }
        });
    };

    var handleUpdateProgress = function () {
        console.log("handleUpdateBMCProgress");

        $(".updateBMC").on('click', function () {
            console.log("Saving Progress..");

            let jsonData = {};
            jsonData['data'] = parseUpdate();

            //console.log("JSON SENT => " + JSON.stringify(jsonData));

            var msgHTML = "";

            $.ajaxSetup({
                headers: {
                    'X-CSRF-TOKEN': $('meta[name="csrf-token"]').attr('content')
                }
            });
            // data:  JSON.stringify(jsonData),
            $.ajax({
                type: 'POST',
                url: postProgressURL,
                data: jsonData,
                dataType: 'json',
                success: function (data) {
                    //console.log("Success +++> ");
                    //console.log(data);

                    msgHTML = '<div class="alert alert-primary" role="alert">'
                        + 'Record Added Successfuly '
                        + '</div>';
                },
                error: function (data) {

                    msgHTML = '<div class="alert alert-danger" role="alert">'
                        + 'Oops! An Error Occured'
                        + '</div>';
                }
            });

        });
    };

    /**
     * Get All Notes
     */
    var handleFetchProgress = function () {
        console.log("handleFetchBMCProgress");

        $.post('canvas?fnct=getBMCProgress', {}, function (mData) {
            //console.log(mData);
            var data = mData.bmc_data;

            assignNotes(data);
        });
    };

    return {
        //main function to initiate the theme
        init: function (Args) {
            args = Args;

            handleUpdateProgress();
            handleAddNote();
            handleFetchProgress();
        }
    }

}();

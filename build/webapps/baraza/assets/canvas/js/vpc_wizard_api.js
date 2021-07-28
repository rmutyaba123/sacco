var vpcWizardApi = function () {

    var domainUrl = 'http://localhost:3001/api';

    // addNote
    // getNotes
    var postProgressURL = 'canvas?fnct=updateVPCProgress';
    var postAddNoteURL = 'canvas?fnct=addVpcNote';

    var allNotes = $("#m_form");

    var handleAddNote = function () {
        console.log("handleAddVPCNote");
        
        $(".saveVPC").on('click', function () {

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
        console.log("handleUpdateVPCProgress");
        
        $(".updateVPC").on('click', function () {
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
        console.log("handleFetchVPCProgress");

        $.post('canvas?fnct=getVPCProgress', {}, function (mData) {
            //console.log(mData);
            var data = mData.vpc_data;

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

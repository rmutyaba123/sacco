let standupApi = function () {

    let domainUrl = 'http://localhost:3001/api';

    // addMessage
    // getMessages
    let postMessageURL = 'canvas?fnct=addStandupMessage';
    let getMessagesURL = 'canvas?fnct=getStandupMessages';
    let getLastMessageURL = 'canvas?fnct=getLastMessage';
    let getScrumBoardURL = 'canvas?fnct=getScrumBoard';
    let postChatURL = 'canvas?fnct=addChatMessage';

    let btnSubmitMessage = $("#modalMessageSubmit");
    let btnSubmitChat = $("#submitChat");
    let boardsList = $(".board-name");
    let boardTitle = $("#board-title");

    /**
     * Add Message
     */
    let handleSubmitMessage = function () {
        //console.log("handleSubmitMessage");
        
        btnSubmitMessage.on('click', function () {
            if (CKEDITOR.instances['inputYesterday'].getData() == "") {
                $("#err-yesterday").removeClass('d-none');return;}
                $("#err-yesterday").addClass('d-none');
            if (CKEDITOR.instances['inputTodo'].getData() == "") {
                $("#err-todo").removeClass('d-none');return;}
                $("#err-todo").addClass('d-none');
            
            let board = {};
            board['board_name'] = boardTitle.text();
            board['board_id'] = boardTitle.attr("name");

            //console.log(`Board: ${JSON.stringify(board)}`);

            let jsonData = prepareMessage();

            //console.log("JSON SENT => " + JSON.stringify(jsonData));

            $("#standup_modal").modal('hide'); //hide modal
            $("#message-container").html("");//clear board
            $.ajaxSetup({
                headers: {
                    'X-CSRF-TOKEN': $('meta[name="csrf-token"]').attr('content')
                }
            });

            $.ajax({
                type: 'POST',
                url: postMessageURL,
                data: jsonData,
                dataType: 'json',
                beforeSend: function () {
                    //close modal
                },
                success: function (mData) {
                    //console.log(mData);
                    let data = mData.messages;

                    displayMessages(data,board,"load");
                    //handleFetchBoards();

                    $("#standup_modal").modal('hide');
                    //Clear modal inputs
                    CKEDITOR.instances['inputTodo'].setData("");
                    CKEDITOR.instances['inputYesterday'].setData("");
                    CKEDITOR.instances['inputImpediments'].setData("");
                },
                error: function (mData) {
                    console.log("Error +++> ");
                    console.log(mData);
                }
            });
        });
    };

    let handleSubmitChat = function () {
        //console.log("handleSubmitChat");
        
        btnSubmitChat.on('click', function () {
            if (CKEDITOR.instances['message-input'].getData() == "") {
                $("#err-msg").removeClass('d-none');return;}

            $("#submitChat").prop("disabled", true);
            $("#err-msg").addClass('d-none');
            
            let board = {};
            board['board_name'] = boardTitle.text();
            board['board_id'] = boardTitle.attr("name");

            //console.log(`Board: ${JSON.stringify(board)}`);

            let jsonData = prepareChat();

            //console.log("JSON SENT => " + JSON.stringify(jsonData));
            $("#message-container").html("");//clear board

            $.ajaxSetup({
                headers: {
                    'X-CSRF-TOKEN': $('meta[name="csrf-token"]').attr('content')
                }
            });

            $.ajax({
                type: 'POST',
                url: postChatURL,
                data: jsonData,
                dataType: 'json',
                beforeSend: function () {
                    //close modal
                },
                success: function (mData) {
                    //console.log(mData);
                    let data = mData.messages;

                    displayMessages(data,board,"load");
                    //handleFetchBoards();

                    //$("#message-input").val("");
                    CKEDITOR.instances['message-input'].setData('');
                    $("#submitChat").prop("disabled", false);
                },
                error: function (mData) {
                    console.log("Error +++> ");
                    console.log(mData);
                }
            });
        });
    };

    let handleFetchBoards = function () {
        //console.log("handleFetchBoards");

        $.post('canvas?fnct=getScrumBoards', {}, function (mData) {
            //console.log(mData);
            let data = mData.boards;

            displayBoards(data);

            handleInitialize();

            if (data.length>0) {
                handleFetchMessages(data.shift());
            }
        });
    };

    let handleFetchMessages = function (board) {
        //console.log("Fetching Messages...");

        let jsonData = {};
        jsonData['scrum_board_id'] = board.board_id;
        jsonData['last_timestamp'] = "";
        console.log("JSON SENT => " + JSON.stringify(jsonData));

        $("#message-container").html("");//clear board
        $.ajaxSetup({
            headers: {
                'X-CSRF-TOKEN': $('meta[name="csrf-token"]').attr('content')
            }
        });

        $.ajax({
            type: 'POST',
            url: getMessagesURL,
            data: jsonData,
            dataType: 'json',
            success: function (mData) {
                //console.log(mData);

                let data = mData.messages;
                displayMessages(data, board, "load");
            },
            error: function (mData) {
                console.log("Error +++> ");
                console.log(mData);
            }
        });

        $("#standupAddBtn").prop("disabled", false);
        $("#submitChat").prop("disabled", false);
        //handleLastMessage();
    };

    let handleRecentMessages = function (board) {
        //console.log("Fetching Recent Messages...");

        let jsonData = {};
        jsonData['scrum_board_id'] = board.board_id;
        jsonData['last_timestamp'] = getLastCreated();
        //console.log("JSON SENT => " + JSON.stringify(jsonData));

        $.ajaxSetup({
            headers: {
                'X-CSRF-TOKEN': $('meta[name="csrf-token"]').attr('content')
            }
        });

        $.ajax({
            type: 'POST',
            url: getMessagesURL,
            data: jsonData,
            dataType: 'json',
            success: function (mData) {
                //console.log(mData);

                let data = mData.messages;
                displayMessages(data, board, "append");
            },
            error: function (mData) {
                console.log("Error +++> ");
                console.log(mData);
            }
        });
    };

    let handleGetBoard = function(boardId) {
        //console.log("handleGetBoard");

        let jsonData = {};
        jsonData['scrum_board_id'] = boardId;
        //console.log("JSON SENT => " + JSON.stringify(jsonData));

        $.ajaxSetup({
            headers: {
                'X-CSRF-TOKEN': $('meta[name="csrf-token"]').attr('content')
            }
        });

        $.ajax({
            type: 'POST',
            url: getScrumBoardURL,
            data: jsonData,
            dataType: 'json',
            success: function (mData) {
                //console.log(mData);

                let data = mData.details;
                displayBoardDetails(data);
            },
            error: function (mData) {
                console.log("Error +++> ");
                console.log(mData);
            }
        });
    }

    let handleLastMessage = function () {
        //console.log("handleLastMessage");

        $("#standupAddBtn").click(function () {
            $("#inputYesterday").val("");

            let jsonData = {};
            jsonData['scrum_board_id'] = boardTitle.attr("name");
            //console.log("JSON SENT => " + JSON.stringify(jsonData));

            $.ajaxSetup({
                headers: {
                    'X-CSRF-TOKEN': $('meta[name="csrf-token"]').attr('content')
                }
            });

            $.ajax({
                type: 'POST',
                url: getLastMessageURL,
                data: jsonData,
                dataType: 'json',
                success: function (mData) {
                   // console.log(mData);

                    let data = mData.message;
                    displayYesterday(data);
                },
                error: function (mData) {
                    console.log("Error +++> ");
                    console.log(mData);
                }
            });
        }); 
    };

    let handleInitialize = function () {
        const board = {};

        $(".board-name").click(function () {
            let boardId = $(this).attr('id');
            board['board_id'] = boardId;
            board['board_name'] = $(this).find('.title').text();
            //console.log(`ID:${board['board_id']} Name:${board['board_name']}`);

            handleFetchMessages(board);
            handleGetBoard(boardId);

            //hide side toggle/mobile
            if( $(".offcanvas-mobile-overlay").length ) {
                $("#kt_chat_aside").toggleClass("offcanvas-mobile-on");
                $(".offcanvas-mobile-overlay").remove();
            }
        });

        $("#refresh-button").click(function () {
            board['board_name'] = boardTitle.text();
            board['board_id'] = boardTitle.attr("name");

            if (board.id != "") {
                handleFetchMessages(board);
            }
            
        });

        setInterval( function() {
            board['board_name'] = boardTitle.text();
            board['board_id'] = boardTitle.attr("name");

            if (board.id != "") {
                handleRecentMessages(board);
            }
            //handleFetchBoards();

        },30000);
    };

    return {
        init: function (Args) {
            args = Args;

            handleFetchBoards();
            handleSubmitMessage();
            handleSubmitChat();
            handleLastMessage();
        }
    }

}();

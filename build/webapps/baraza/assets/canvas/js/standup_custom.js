const boardsList = $("#board-list");
const boardTitle = $("#board-title");
const boardMessages = $("#message-container");
const chatInput = $("#message-input");

var messageForm = $("#message-form");
var lastCreated = "";

let prepareMessage = function() {
    var standupMessage = messageForm.serializeArray();
    let data = {};
    data['scrum_board_id'] = boardTitle.attr("name");

    $.each(standupMessage, function (i, field) {
        /*data[field.name] = field.value.replace(/\n\r/g,"").replace(/\n/g,'<br>');*/
        /*data[field.name] = $("[name ="+field.name+"]").data('markdown').parseContent().replace(/\n/g,'<br>');*/
        let id = $("[name ="+field.name+"]").attr("id");
        data[field.name] =  CKEDITOR.instances[id].getData();
    });

    return data;
};

let prepareChat = function() {
    let data = {};
    data['scrum_board_id'] = boardTitle.attr("name");
    /*data['message'] = chatInput.val().replace(/\n/g,'<br>');*/
    /*data['message'] = chatInput.data('markdown').parseContent().replace(/\n/g,'<br>');*/
    data['message'] = CKEDITOR.instances['message-input'].getData();

    return data;
};

function displayBoards(data) {

    let appendBoardListHtml = '';    

    for (let i = 0; i < data.length; i++) {
        appendBoardListHtml += parseBoard(data[i]);
    }

    boardsList.html(appendBoardListHtml);
}

function displayMessages(data, board, action) {
    let countLabel = $(".label-success#board-"+board.board_id);
    let currentCount  = parseInt(countLabel.html());
    let todayCount = 0;

    let appendBoardHtml = '';
    var messageDate = moment();
    var created;

    for (let i = 0; i < data.length; i++) {
        created = moment(data[i].created);

        if ( !created.isSame(messageDate, 'day') ) {
            appendBoardHtml += '<div class="d-flex flex-column align-items-center"><span class="m-badge bg-dark text-white m-badge--wide my-2">'+relativeDate(data[i].created)+'</span></div>';
            messageDate = created;
        }

        if (created.isSame(moment(), 'day')) {
            todayCount+=1;
        }

        if (data[i].message_type == 'standup_message') {
            appendBoardHtml += parseMessage(data[i]);
        } else {
            appendBoardHtml += parseChat(data[i]);
        }
    }

    if (data.length > 0) {
        lastCreated = data[data.length-1].created;
    }
    

    if (action == "append") {
        var old_scroll = boardMessages.scrollTop();
        boardMessages.append(appendBoardHtml);
        boardMessages.scrollTop(old_scroll);
        countLabel.html(currentCount + data.length);
    } else {
        boardMessages.html(appendBoardHtml);
        boardMessages.scrollTop(boardMessages[0].scrollHeight);
        countLabel.html(todayCount);
    }

    boardTitle.text(board.board_name);
    boardTitle.attr("name", board.board_id);
    boardMessages.find('p').addClass('mb-0 ml-2 font-size-sm');
    boardMessages.find('span').removeAttr('style');
}

function displayYesterday(data) {
    //$("#inputYesterday").markdown({autofocus:false});
    if (data.length != 0) {
        let lastMessage = data.shift();
        let dateCreated = moment(lastMessage.created).clone().startOf('day');
        let today = moment().clone().startOf('day');

        if (today.diff(dateCreated, 'days') == 1 || (dateCreated.day() == 5 && today.diff(dateCreated, 'days') == 3) ) {
            //$("#inputYesterday").data('markdown').setContent( $(lastMessage.todo).text() );
            //$("#inputYesterday").data('markdown').setContent( lastMessage.todo );
            CKEDITOR.instances['inputYesterday'].setData( lastMessage.todo );
        }
    }
}

function displayBoardDetails(data) {
    if (data.length !=0) {
        let boardDetails = data.shift();
        
        $("#detailsTitle").text(boardDetails.scrum_board_name);
        $("#members").text(boardDetails.member_count);
        $("#time").text(boardDetails.standup_time);
        $("#details").text(boardDetails.details);
    }
}

function parseBoard(board) {
    let boardHtml = '';
    let boardId = board.board_id;
    let boardName = board.board_name;
    let messageCount = board.messagecount;

    boardHtml += '<!--begin:Board-->' +
        '<a href="#" class="d-flex align-items-center board-name justify-content-between p-2" id="'+boardId+'">' +
            '<div class="d-flex align-items-center">' +
                '<div class="d-flex flex-column title">' +
                    '<span class="font-weight-bold font-size-sm">'+boardName+'</span>' +
                '</div>' +
            '</div>' +
            '<div class="d-flex flex-column align-items-end">' +
                '<span class="label label-sm label-success" id="board-'+boardId+'">'+messageCount+'</span>' +
            '</div>' +
        '</a>' +
        '<!--end:Board-->';

    return boardHtml;
}

function parseMessage(message) {

    let messageHtml = '';
    let messageUser = message.user;
    let messageTime = message.created;
    let messageYesterday = message.yesterday;
    let messageToday = message.todo;
    let messageImpediments = '<h4 class="text-muted font-size-sm mt-1 mb-0">Impediments</h4>' + message.impediments;

    if (message.impediments == "" || message.impediments == undefined) {
        messageImpediments = "";
    }

    messageHtml += '<!--begin::Message-->' +
        '<div class="d-flex flex-column mb-1 px-3 py-2 message-box align-items-start">'+
            '<div class="d-flex align-items-center">' +
                '<div>' +
                    '<span class="font-weight-bold text-muted font-size-h6">'+messageUser+'</span>' +
                    '<span class="text-dark-50 font-size-sm mx-2">'+relativeTime(messageTime)+'</span>' +
                '</div>' +
            '</div>' +
            '<div class="mt-1 rounded px-3 text-dark text-left">' +
                '<h4 class="text-muted font-size-sm mt-1 mb-0">Done Yesterday</h4>' +
                messageYesterday +
                '<h4 class="text-muted font-size-sm mt-1 mb-0">To Do Today</h4>' +
                messageToday + messageImpediments +
            '</div>' +
        '</div>' +
        '<hr>' +
        '<!--end::Message-->';

    return messageHtml;
}

function parseChat(message) {

    let messageHtml = '';
    let messageUser = message.user;
    let messageTime = message.created;
    let messageChat = message.scrum_chat;

    messageHtml += '<!--begin::Message-->' +
        '<div class="d-flex flex-column mb-1 px-3 py-2 message-box align-items-start">'+
            '<div class="d-flex align-items-center">' +
                '<div>' +
                    '<span class="font-weight-bold text-muted font-size-h6">'+messageUser+'</span>' +
                    '<span class="text-dark-50 font-size-sm mx-2">'+relativeTime(messageTime)+'</span>' +
                '</div>' +
            '</div>' +
            '<div class="mt-1 rounded px-3 text-dark text-left">' + messageChat +
            '</div>' +
        '</div>' +
        '<hr>' +
        '<!--end::Message-->';

    return messageHtml;
}

function relativeTime(timestamp) {
   //return moment(timestamp).fromNow();
   return moment(timestamp).format("h:mm A");
}

function relativeDate(timestamp) {
    let dateString = moment(timestamp).format("dddd, MMMM Do, YYYY");

    if ( moment(timestamp).isSame(moment(), 'day') ) {
        dateString = "Today, "+moment(timestamp).format("MMMM Do");
    }

    return dateString;
}

function getLastCreated() {
    return lastCreated;
} 
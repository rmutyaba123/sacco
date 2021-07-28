
<script>
	var Calendar = function() {


    return {
        //main function to initiate the module
        init: function() {
            Calendar.initCalendar();
        },

        initCalendar: function() {

            if (!jQuery().fullCalendar) {
                return;
            }

            var date = new Date();
            var d = date.getDate();
            var m = date.getMonth();
            var y = date.getFullYear();

            var h = {};

            if (Metronic.isRTL()) {
                if ($('#calendar').parents(".portlet").width() <= 720) {
                    $('#calendar').addClass("mobile");
                    h = {
                        right: 'title, prev, next',
                        center: '',
                        left: 'agendaDay, agendaWeek, month, today'
                    };
                } else {
                    $('#calendar').removeClass("mobile");
                    h = {
                        right: 'title',
                        center: '',
                        left: 'agendaDay, agendaWeek, month, today, prev,next'
                    };
                }
            } else {
                if ($('#calendar').parents(".portlet").width() <= 720) {
                    $('#calendar').addClass("mobile");
                    h = {
                        left: 'title, prev, next',
                        center: '',
                        right: 'today,month,agendaWeek,agendaDay'
                    };
                } else {
                    $('#calendar').removeClass("mobile");
                    h = {
                        left: 'title',
                        center: '',
                        right: 'prev,next,today,month,agendaWeek,agendaDay'
                    };
                }
            }

            var initDrag = function(el) {
                // create an Event Object (http://arshaw.com/fullcalendar/docs/event_data/Event_Object/)
                // it doesn't need to have a start or end
                var eventObject = {
                    title: $.trim(el.text()) // use the element's text as the event title
                };

                // store the Event Object in the DOM element so we can get to it later
                el.data('eventObject', eventObject);

                // make the event draggable using jQuery UI
                el.draggable({
                    zIndex: 999,
                    revert: true, // will cause the event to go back to its
                    revertDuration: 0 //  original position after the drag
                });
            };

            var addEvent = function(title) {
                title = title.length === 0 ? "Untitled Event" : title;
                var html = $('<div class="external-event label label-default">' + title + '</div>');
                jQuery('#event_box').append(html);
                initDrag(html);
            };

			/* initialize the external events
			-----------------------------------------------------------------*/
			$('#external-events .fc-event').each(function() {
		
				// create an Event Object (http://arshaw.com/fullcalendar/docs/event_data/Event_Object/)
				// it doesn't need to have a start or end
				var eventObject = {
					title: $.trim($(this).text()) // use the element's text as the event title
				};
			
				// store the Event Object in the DOM element so we can get to it later
				$(this).data('eventObject', eventObject);
			
				// make the event draggable using jQuery UI
				$(this).draggable({
					zIndex: 999,
					revert: true,      // will cause the event to go back to its
					revertDuration: 0  //  original position after the drag
				});
			
			});


            $('#calendar').fullCalendar('destroy'); // destroy the calendar
            $('#calendar').fullCalendar({ //re-initialize the calendar
                header: h,
                defaultView: 'agendaWeek', // change default view with available options from http://arshaw.com/fullcalendar/docs/views/Available_Views/ 
                slotMinutes: 15,
                editable: true,
                droppable: true, // this allows things to be dropped onto the calendar !!!
                drop: function(date, jsEvent, ui) { // this function is called when something is dropped
                    // retrieve the dropped element's stored Event Object
                    var originalEventObject = $(this).data('eventObject');
                    // we need to copy it, so that multiple events don't have a reference to the same object
                    var copiedEventObject = $.extend({}, originalEventObject);

                    // assign it the date that was reported
                    copiedEventObject.allDay = false;
                    copiedEventObject.start = date;
                    copiedEventObject.end = date + (9*60*60*1000);
                    copiedEventObject.className = $(this).attr("data-class");

					// post the event on server
					addCalendarEvent(copiedEventObject, this.getAttribute('key_field_id'));

                    // render the event on the calendar
                    // the last `true` argument determines if the event "sticks" (http://arshaw.com/fullcalendar/docs/event_rendering/renderEvent/)
                    //$('#calendar').fullCalendar('renderEvent', copiedEventObject, true);
                },

				eventResize: function(event, delta, revertFunc) {
					resizeCalendarEvent(event);
				},

				eventDrop: function(event, delta, revertFunc) {
					moveCalendarEvent(event);
				},

				eventRender: function(event, element) {
					 $(element).on({
						 dblclick: function() {
							console.log("eventRender doubleClick");
							if (confirm("Do you want to delete the schedule?")) {
								delCalendarEvent(event);
								$('#calendar').fullCalendar('removeEvents', event.id);
							} 
						 }
					 });
				},
				
				events: {
					url: 'webcalendar'
				}

            });

        }

    };

}();

function addCalendarEvent(event, keyId) {
	var start = new Date(event.start);
	var end = new Date(event.end);
	return $.post("ajax?fnct=caladd", {"startdate":start.toISOString(), "enddate":end.toISOString(), "keyId":keyId}, function(data) {
console.log(data);
		if(data.status == 'OK') {
			$('#calendar').fullCalendar('refetchEvents');
		}
    }, "JSON");
}

function resizeCalendarEvent(event) {
	var start = new Date(event.start);
	var end = new Date(event.end);
	return $.post("ajax?fnct=calresize", {"startdate":start.toISOString(), "enddate":end.toISOString(), "id":event.id}, function(data) {
console.log(data);
    }, "JSON");
}

function moveCalendarEvent(event) {
	var start = new Date(event.start);
	var end = new Date(event.end);
	return $.post("ajax?fnct=calmove", {"startdate":start.toISOString(), "enddate":end.toISOString(), "id":event.id}, function(data) {
console.log(data);
    }, "JSON");
}

function delCalendarEvent(event) {
	return $.post("ajax?fnct=caldel", {"id":event.id}, function(data) {
console.log(data);
    }, "JSON");
}


</script>

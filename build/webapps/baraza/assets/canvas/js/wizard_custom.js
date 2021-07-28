const KeyPartners = '17';
const KeyActivities = '15';
const KeyResources = '16';
const ValuePrepositions = '10';
const customerRelationships = '13';
const channels = '11';
const customerSegments = '12';
const costStructure = '18';
const revenueStreams = '14';
const brainStorm = '19';

const customerJobs = '1';
const Gains = '2';
const Pains = '3';
const GainCreators = '4';
const PainRelievers = '5';
const ProductsServices = '6';

const customerJobsField = $("#Customer_Job");
const gainsField = $("#Gain");
const painsField = $("#Pain");
const gainCreatorsField = $("#Gain_Creator");
const painRelieversField = $("#Pain_Reliver");
const productsServicesField = $("#Product_or_Service");

const keyPartnersField = $("#Key_Partners");
const keyActivitiesField = $("#Key_Activities");
const keyResourcesField = $("#Key_Resources");
const valuePrepositionsField = $("#Value_Proposition");
const customerRelationshipsField = $("#Customer_Relationship");
const channelsField = $("#Channel");
const customerSegmentsField = $("#Customer_Segment");
const costStructureField = $("#Cost_Structure");
const revenueStreamsField = $("#Revenue_Streams");
const brainStormField = $("#Brain_Storming");

var allNotes = $("#m_form");

var parseNotes = function() {
    var step = $(".m-wizard__step--current .steps").text().trim();
    var stepId = step.replace(/\s/g, "_");
    var segment = step.replace(/\s/g, "");

    var data = []; //array to store all notes
    let fieldValue = $("#"+stepId).val();   //get Field

    if (fieldValue != "" && fieldValue != undefined) {
        let notesArray = fieldValue.split('\n'); //get each texarea line as single note

        for(let noteContent of notesArray) {
            if (noteContent != "" && noteContent != "\r" ) {
                let note = {};
                note['note_segment'] = checkSegment(segment);
                note['note_label'] =  randomLabl();
                note['note_content'] = noteContent.replace('\r','');

                data.push(note);
            }
        }
    }

    return data;
};

var parseUpdate = function() {
    var json = allNotes.serializeArray();
    var formData = [];

    $.each(json, function (i, field) {
        let jsonObject = {};
        jsonObject['name'] = field.name;
        jsonObject['value'] = field.value.replace(/\n\r/g, "");

        formData.push(jsonObject);
    });

    return JSON.stringify(formData);
}

/**
 * Check the right segment
 * @param {*} segment 
 */
function checkSegment(segment) {

    if (segment == 'KeyPartners') {
        return KeyPartners;
    } else if (segment == 'KeyActivities') {
        return KeyActivities;
    } else if (segment == 'KeyResources') {
        return KeyResources;
    } else if (segment == 'ValueProposition') {
        return ValuePrepositions;
    } else if (segment == 'CustomerRelationship') {
        return customerRelationships;
    } else if (segment == 'Channel') {
        return channels;
    } else if (segment == 'CustomerSegment') {
        return customerSegments;
    } else if (segment == 'CostStructure') {
        return costStructure;
    } else if (segment == 'RevenueStreams') {
        return revenueStreams;
    } else if (segment == 'BrainStorming') {
        return brainStorm;
    } else if (segment == 'ProductorService') {
        return ProductsServices;
    } else if (segment == 'GainCreator') {
        return GainCreators;
    } else if (segment == 'PainReliver') {
        return PainRelievers;
    } else if (segment == 'Gain') {
        return Gains;
    } else if (segment == 'Pain') {
        return Pains;
    } else if (segment == 'CustomerJob') {
        return customerJobs;
    } 
    else {
        return "None";
    }
}


//Randomize note labels
var randomLabl = function() {
    var labels = ["an","gn","yn","rn","en"];
    return labels[Math.floor(Math.random() * 5)];
}

function appendNote(data) {

    var noteContent = data.note_content+'\n';

    return noteContent;
}

/**
 * Ensures the notes are divided in proper segment
 * @param {*} data 
 */
function assignNotes(mData) {

    let dataUpdate = mData.shift();
    if ( $.isEmptyObject(dataUpdate) ) {return;}

    let data = JSON.parse(dataUpdate.wizard_data);

    //console.log(data);

    for(let field of data) {

        if (field.value != undefined) {
            if (field.name == 'KeyPartners') {
                keyPartnersField.text(field.value);
            } else if (field.name == 'KeyActivities') {
                keyActivitiesField.text(field.value);
            } else if (field.name == 'KeyResources') {
                keyResourcesField.text(field.value);
            } else if (field.name == 'ValueProposition') {
                valuePrepositionsField.text(field.value);
            } else if (field.name == 'CustomerRelationship') {
                customerRelationshipsField.text(field.value);
            } else if (field.name == 'Channel') {
                channelsField.text(field.value);
            } else if (field.name == 'CustomerSegment') {
                customerSegmentsField.text(field.value);
            } else if (field.name == 'CostStructure') {
                costStructureField.text(field.value);
            } else if (field.name == 'RevenueStreams') {
                revenueStreamsField.text(field.value);
            }else if (field.name == 'BrainStorming') {
                brainStormField.text(field.value);
            } 
            else if (field.name == 'ProductorService') {
                productsServicesField.text(field.value);
            } else if (field.name == 'GainCreator') {
                gainCreatorsField.text(field.value);
            } else if (field.name == 'PainReliever') {
                painRelieversField.text(field.value);
            } else if (field.name == 'Gain') {
                gainsField.text(field.value);
            } else if (field.name == 'Pain') {
                painsField.text(field.value);
            } else if (field.name == 'CustomerJob') {
                customerJobsField.text(field.value);
            }
        }

    }

}
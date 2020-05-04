
function toggleAttachmentsColored( Id, Ord, Cat, Action, AttId) {
    if ( jQuery(".attachtoggle-"+Id).length ) {
	// console.log("katt, load before");
	jQuery(".attachtoggle-"+Id).load('<%RT->Config->Get('WebPath')%>/Helpers/Toggle/AttachmentsColored', {'id':Id, 'AttOrd': Ord, 'AttCat': Cat, 'AttAction': Action, 'AttId': AttId});
    }
}

function setFolder( attID, node ) {
	console.log(attID + " *** " + node.value);
	jQuery.ajax({
		type: 'POST',
		url: '<%RT->Config->Get('WebPath')%>/Ajax/AjaxModifyFolder',
		data: {
			'Value' : node.value,
			'attachId' : attID
		}
	});
}



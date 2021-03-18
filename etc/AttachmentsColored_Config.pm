Set(%AttachmentCategories, (
	'A' => '#FF6347',
	'B' => '#90EE90',
	'C' => '#87CEFA',
	'D' => '#fCDC8C',
	'hidden' => '#DCDCDC'
));

Set($ConfigTicketID, 2);

Set($DefaultFolderStructureTicketID, 2);

Set($Scope, "(id = %d OR 'CF.{Munkaszám}' = '%s') AND (Status = '__Active__' OR Status = '__Inactive__')");

Set(%RabbitMQ, ('enabled' => 0, 'host' => 'petky-dav', 'port' => 5672, 'login' => 'admin', 'passw' => 'admin'));

1;

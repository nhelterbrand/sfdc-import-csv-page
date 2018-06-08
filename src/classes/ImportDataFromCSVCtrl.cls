/**
 * Controller for ImportDataFromCSVPage to upload a CSV of records at once
 * @author Nate Helterbrand
 * @created May 2018
 */
public without sharing class ImportDataFromCSVCtrl {
    public Blob CSVFileBody {get;set;}
    public String recordIndexToRemove {get;set;}

    public Boolean allowPartialSuccess {
        get {
            return (allowPartialSuccess == null) ? true : allowPartialSuccess;
        }
        set;
    }

    public String dateInputFormat {
        get {
            return (dateInputFormat == null) ? 'MM/DD/YYYY' : dateInputFormat;
        }
        set;
    }

    public String selectedObject {
        get {
            return (selectedObject == null) ? SObjectType.Account.getName() : selectedObject;
        }
        set;
    }

    public String selectedFieldSet {
        get {
            return (selectedFieldSet == null) ? 'All' : selectedFieldSet;
        }
        set;
    }

    public List<SObjectRecordWrapper> sObjectRecords {
        get {
            return (sObjectRecords == null) ? new List<SObjectRecordWrapper>() : sObjectRecords;
        }
        set;
    }

    public List<SObjectField> fieldSetSObjectFields {
        get {
            return (fieldSetSObjectFields == null) ? new List<SObjectField>() : fieldSetSObjectFields;
        }
        set;
    }

    public List<SelectOption> sObjectOptions {
        get {
            if (sObjectOptions == null) {
                fetchSObjectOptions();
            }

            return sObjectOptions;
        }
        set;
    }

    public List<SelectOption> fieldSetOptions {
        get {
            if (fieldSetOptions == null) {
                fetchFieldSetOptions();
            }
            
            return fieldSetOptions;
        }
        set;
    }

    public List<SelectOption> dateInputFormatOptions {
        get {
            dateInputFormatOptions = new List<SelectOption>();
            dateInputFormatOptions.add(new SelectOption('Local', System.Label.Date_Local_Format_Option_Text));
            dateInputFormatOptions.add(new SelectOption('System', System.Label.Date_System_Format_Option_Text));

            return dateInputFormatOptions;
        }
        set;
    }

    // class to contain field information
    public class SObjectField {
        public String type;
        public String label {get;set;}
        public String developerName {get;set;}
        public Boolean required {get;set;}
    }

    // wrapper class to display records in table
    public class SObjectRecordWrapper {
        public List<String> errorMessages {get;set;}
        public SObject record {get;set;}
    }

    // methods fired from visualforce actions

    public void fetchFieldSetOptions() {
        if (selectedObject != null) {
            List<Schema.FieldSet> fieldSetList = Schema.getGlobalDescribe().get(selectedObject).getDescribe().FieldSets.getMap().values();
            fieldSetOptions = new List<SelectOption>();
            fieldSetOptions.add(new SelectOption('All', System.Label.All_Fields_Text)); 

            for (Schema.FieldSet fs : fieldSetList) {
                fieldSetOptions.add(new SelectOption(fs.getName(), fs.getLabel()));
            }
        }
    }  

    public void fetchSObjectOptions() {
        List<Schema.SObjectType> gd = Schema.getGlobalDescribe().values();   
        sObjectOptions = new List<SelectOption>();
        
        for(Schema.SObjectType f : gd) {
            Schema.DescribeSObjectResult d = f.getDescribe();

            if (d.isCreateable()) {
                sObjectOptions.add(new SelectOption(f.getDescribe().getName(),f.getDescribe().getLabel()));
            }
        }
    }

    public void transformCSVFileBodyToRecords() {
        if (CSVFileBody == null) {
            // cannot load a file that doesnt exist
            displayMessage(ApexPages.Severity.ERROR, System.Label.Choose_File_Message);
        } else {
            try {
                sObjectRecords = new List<SObjectRecordWrapper>();
                String CSVString = CSVFileBody.toString();
                List<List<String>> parsedCSV = parseCSV(CSVString, true);

                for (Integer i = 0; i < parsedCSV.size(); i++) {
                    SObject sr = Schema.getGlobalDescribe().get(selectedObject).newSObject();
                    SObjectRecordWrapper srWrap = createSObjectWrapper(fieldSetSObjectFields, parsedCSV[i]);

                    sObjectRecords.add(srWrap);
                }
            } catch (Exception e) {
                displayMessage(ApexPages.Severity.ERROR, e.getMessage());
            }
        }
    }

    public void insertSObjectRecords() {
        List<Database.SaveResult> saveResultList;
        List<SObject> sObjectList = new List<SObject>();
        for (SObjectRecordWrapper srw : sObjectRecords) {
            sObjectList.add(srw.record);
        }

        if (allowPartialSuccess == true) {
            saveResultList = Database.insert(sObjectList, false);
            sObjectRecords = new List<SObjectRecordWrapper>();
            Integer recordsInsertedSuccessfully = 0;
            Integer recordsInsertedWithError = 0;

            for (Integer i = 0; i < sObjectList.size(); i++) {
                if (saveResultList[i].isSuccess()) {
                    recordsInsertedSuccessfully++;
                } else {
                    recordsInsertedWithError++;

                    SObjectRecordWrapper srw = new SObjectRecordWrapper();
                    srw.record = sObjectList[i];
                    srw.errorMessages = new List<String>();
                    
                    for (Database.Error err : saveResultList[i].getErrors()) {
                        srw.errorMessages.add(err.getMessage());
                        System.debug(LoggingLevel.ERROR, err.getMessage());
                    }

                    sObjectRecords.add(srw);
                }
            }

            if (recordsInsertedSuccessfully > 0 && recordsInsertedWithError == 0) {
                displayMessage(
                    ApexPages.Severity.CONFIRM, 
                    String.format(
                        System.Label.Success_Insert_Message, 
                        new List<String>{String.valueOf(recordsInsertedSuccessfully), selectedObject}
                    )
                );

                if (recordsInsertedSuccessfully == sObjectList.size()) {
                    CSVFileBody = null;
                }
            }

            if (recordsInsertedWithError > 0 && recordsInsertedSuccessfully == 0) {
                displayMessage(
                    ApexPages.Severity.ERROR, 
                    String.format(
                        System.Label.Error_Insert_Message, 
                        new List<String>{String.valueOf(recordsInsertedWithError)}
                    )
                );
            }

            if (recordsInsertedSuccessfully > 0 && recordsInsertedWithError > 0) {
                displayMessage(
                    ApexPages.Severity.WARNING, 
                    String.format(
                        System.Label.Mixed_Result_Insert_Message, 
                        new List<String>{String.valueOf(recordsInsertedSuccessfully), selectedObject, String.valueOf(recordsInsertedWithError)}
                    )
                );
            }
        } else {
            try {
                insert sObjectList;
                displayMessage(
                    ApexPages.Severity.CONFIRM, 
                    String.format(
                        System.Label.Success_Insert_Message, 
                        new List<String>{String.valueOf(sObjectList.size()), selectedObject}
                    )
                );

                sObjectRecords = new List<SObjectRecordWrapper>();
                CSVFileBody = null;         
            } catch (Exception e) {
                displayMessage(ApexPages.Severity.ERROR, e.getMessage());
            }

        }
    }

    public void clearFile() {
        sObjectRecords = new List<SObjectRecordWrapper>();
        CSVFileBody = null;
    }

    public void addRecordToList() {
        SObjectRecordWrapper srw = createSObjectWrapper(null, null);

        if (sObjectRecords == null || sObjectRecords.size() == 0) {
            sObjectRecords = new List<SObjectRecordWrapper>();
            sObjectRecords.add(srw);
        } else {
            sObjectRecords.add(0, srw);
        }
    }

    public void removeRecordFromList() {
        if (recordIndexToRemove != null) {
            Integer index = Integer.valueOf(recordIndexToRemove);
            sObjectRecords.remove(index);
        }
    }

    // actions that redirect to another visualforce page

    public PageReference downloadCSVTemplate() {
        return Page.ImportDataFromCSVPageTemplateExport; 
    }

    public PageReference step2() {
        populateFieldSetMemberList();
        return Page.ImportDataFromCSVPageStep2;
    }

    public PageReference step1() {
        return Page.ImportDataFromCSVPage;
    }

    // helper functions

    private void populateFieldSetMemberList() {

        if (selectedFieldSet != 'All') {
            fieldSetSObjectFields = new List<SObjectField>();
            List<Schema.FieldSetMember> fieldSetFieldMemberList = Schema.getGlobalDescribe().get(selectedObject).getDescribe().FieldSets.getMap().get(selectedFieldSet).getFields();

            for (Schema.FieldSetMember fsm : fieldSetFieldMemberList) {
                SObjectField sf = new SObjectField();
                sf.label = fsm.getLabel();
                sf.type = fsm.getType().name();
                sf.developerName = fsm.getFieldPath();
                sf.required = fsm.getDBRequired() || fsm.getRequired();

                fieldSetSObjectFields.add(sf);
            }
        } else {
            fieldSetSObjectFields = new List<SObjectField>();
            List<Schema.SObjectField> fieldList = Schema.getGlobalDescribe().get(selectedObject).getDescribe().fields.getMap().values();

            for (Schema.SObjectField sof : fieldList) {
                Schema.DescribeFieldResult dfr = sof.getDescribe();

                if (dfr.isCreateable()) {
                    SObjectField sf = new SObjectField();
                    sf.label = dfr.getLabel();
                    sf.type = dfr.getType().name();
                    sf.developerName = dfr.getName();
                    sf.required = !dfr.isNillable();

                    fieldSetSObjectFields.add(sf);
                }
            }
        }
    }

    private Object putValue(String type, Object value) {
        if (value != '') {
            if (type == 'Datetime') {
                return parseDatetime((String)value);
            } else if (type == 'Date') {
                return parseDate((String)value);
            } else if (type == 'Integer') {
                return Integer.valueOf((String)value);
            } else if (type == 'Double') {
                return Decimal.valueOf((String)value);
            } else if (type == 'Currency') {
                return Decimal.valueOf((String)value);
            } else {
                return value;
            }
        } else {
            return null;
        }
    }

    @TestVisible
    private Date parseDate(String dateInput) {
        Date parsedDate;

        try {
            if (dateInputFormat == 'Local') {
                parsedDate = Date.parse(dateInput);
            } else {
                parsedDate = Date.valueOf(dateInput);
            }
        } catch (Exception e) {
            displayMessage(
                ApexPages.Severity.ERROR, 
                String.format(
                    System.Label.Date_Wrong_Format_Message, 
                    new List<String>{dateInputFormat}
                )
            );
        }

        return parsedDate;
    }

    @TestVisible
    private Datetime parseDatetime(String datetimeInput) {
        Datetime parsedDatetime;

        try {
            if (dateInputFormat == 'Local') {
                parsedDatetime = Datetime.parse(datetimeInput);
            } else {
                if (datetimeInput.contains('Z')) {
                    datetimeInput = datetimeInput.replace('Z', ' ');
                }

                if (datetimeInput.contains('T')) {
                    datetimeInput = datetimeInput.replace('T', ' ');
                }

                parsedDatetime = Datetime.valueOf(datetimeInput);
            }
        } catch (Exception e) {
            displayMessage(
                ApexPages.Severity.ERROR, 
                String.format(
                    System.Label.Date_Wrong_Format_Message, 
                    new List<String>{dateInputFormat}
                )
            );
        }

        return parsedDatetime;
    }

    private SObjectRecordWrapper createSObjectWrapper(List<SObjectField> fieldSetSObjectFields, List<String> valueList) {
        SObjectRecordWrapper srWrap = new SObjectRecordWrapper();
        SObject sr;

        if (fieldSetSObjectFields != null) {
            sr = Schema.getGlobalDescribe().get(selectedObject).newSObject();

            for (Integer j = 0; j < fieldSetSObjectFields.size(); j++) {
                SObjectField field = fieldSetSObjectFields[j];
                sr.put(field.developerName, putValue(field.type, valueList[j]));
            }
        } else {
            sr = Schema.getGlobalDescribe().get(selectedObject).newSObject(null, true);
        }

        srWrap.record = sr;  
        srWrap.errorMessages = new List<String>();

        return srWrap;
    }

    // initial credit from https://developer.salesforce.com/page/Code_Samples#Parse_a_CSV_with_APEX
    private static List<List<String>> parseCSV(String contents,Boolean skipHeaders) {
        List<List<String>> allFields = new List<List<String>>();

        // replace instances where a double quote begins a field containing a comma
        // in this case you get a double quote followed by a doubled double quote
        // do this for beginning and end of a field
        contents = contents.replaceAll(',"""',',"DBLQT').replaceall('""",','DBLQT",');
        // now replace all remaining double quotes - we do this so that we can reconstruct
        // fields with commas inside assuming they begin and end with a double quote
        contents = contents.replaceAll('""','DBLQT');
        // we are not attempting to handle fields with a newline inside of them
        // so, split on newline to get the spreadsheet rows
        List<String> lines = new List<String>();
        try {
            if (contents.indexOf('\r') != -1) {
                lines = contents.split('\r\n');
            } else {
                lines = contents.split('\n');
            }
        } catch (System.ListException e) {
            System.debug('Limits exceeded?' + e.getMessage());
        }
        Integer num = 0;
        for(String line : lines) {
            System.debug('line before breaking: ' + line);
            // check for blank CSV lines (only commas)
            if (line.replaceAll(',','').trim().length() == 0) {
                System.debug('breaking');
                break;
            }
            
            // adding -1 because there can be empty values in between commas
            List<String> fields = line.split(',', -1);  

            List<String> cleanFields = new List<String>();
            String compositeField;
            Boolean makeCompositeField = false;
            System.debug('fields after split: ' + fields);
            System.debug('fields size: ' + fields.size());
            for(String field : fields) {
                if (field.startsWith('"') && field.endsWith('"')) {
                    cleanFields.add(field.replaceAll('DBLQT','"'));
                } else if (field.startsWith('"')) {
                    makeCompositeField = true;
                    compositeField = field;
                } else if (field.endsWith('"')) {
                    compositeField += ',' + field;
                    cleanFields.add(compositeField.replaceAll('DBLQT','"'));
                    makeCompositeField = false;
                } else if (makeCompositeField) {
                    compositeField +=  ',' + field;
                } else {
                    cleanFields.add(field.replaceAll('DBLQT','"'));
                }
            }
            
            allFields.add(cleanFields);
        }
        if (skipHeaders) allFields.remove(0);
        return allFields;       
    }

    private static void displayMessage(ApexPages.Severity severity, String message) {
        ApexPages.Message successMessage = new ApexPages.Message(severity, message);
        ApexPages.addMessage(successMessage);

        System.debug(LoggingLevel.DEBUG, 'Displaying Message with severity: ' + severity);
        System.debug(LoggingLevel.DEBUG, 'Message displayed: ' + message);
    }
}
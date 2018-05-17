/**
 * Controller for ImportDataFromCSVPage to upload a CSV of records at once
 * @author Nate Helterbrand
 * @created May 2018
 */
public without sharing class ImportDataFromCSVCtrl {

    public List<SelectOption> sObjectOptions;
    public List<SelectOption> fieldSetOptions;
    public Blob CSVFileBody {get;set;}

    public class SObjectField {
        public String type;
        public String label {get;set;}
        public String developerName {get;set;}
    }

    public String selectedObject {
        get {
            if (selectedObject == null) selectedObject = 'Account';
            return selectedObject;
        }
        set;
    }

    public String selectedFieldSet {
        get {
            if (selectedFieldSet == null) selectedFieldSet = 'All';
            return selectedFieldSet;
        }
        set;
    }

    public List<SObject> sObjectRecords {
        get {
            if (sObjectRecords == null) sObjectRecords = new List<SObject>();
            return sObjectRecords;
        }
        set;
    }

    public List<SObjectField> fieldSetSObjectFields {
        get {
            if (fieldSetSObjectFields == null) fieldSetSObjectFields = new List<SObjectField>();
            return fieldSetSObjectFields;
        }
        set;
    }

    public List<SelectOption> getSObjectOptions() {
        if (sObjectOptions == null) {
            fetchSObjectOptions();
        }

        return sObjectOptions;
    }

    public List<SelectOption> getFieldSetOptions() {
        if (fieldSetOptions == null) {
            fetchFieldSetOptions();
        }

        return fieldSetOptions;
    }

    public void fetchFieldSetOptions() {
        if (selectedObject != null) {
            List<Schema.FieldSet> fieldSetList = Schema.getGlobalDescribe().get(selectedObject).getDescribe().FieldSets.getMap().values();
            fieldSetOptions = new List<SelectOption>();
            fieldSetOptions.add(new SelectOption('All', 'All Fields')); 

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

    public void populateFieldSetMemberList() {
        System.debug('selectedObject ' + selectedObject);
        System.debug('selected field set: ' + selectedFieldSet);

        if (selectedFieldSet != 'All') {
            fieldSetSObjectFields = new List<SObjectField>();
            List<Schema.FieldSetMember> fieldSetFieldMemberList = Schema.getGlobalDescribe().get(selectedObject).getDescribe().FieldSets.getMap().get(selectedFieldSet).getFields();

            for (Schema.FieldSetMember fsm : fieldSetFieldMemberList) {
                SObjectField sf = new SObjectField();
                sf.label = fsm.getLabel();
                sf.type = fsm.getType().name();
                sf.developerName = fsm.getFieldPath();

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

                    fieldSetSObjectFields.add(sf);
                }
            }
        }
    }

    public Object putValue(String type, Object value) {
        if (value != '') {
            if (type == 'Datetime') {
                return Date.parse((String)value);
            } else if (type == 'Date') {
                return Date.parse((String)value);
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

    public void transformCSVFileBodyToRecords() {
        try {

            String CSVString = CSVFileBody.toString();
            List<List<String>> parsedCSV = parseCSV(CSVString, true);

            for (Integer i = 0; i < parsedCSV.size(); i++) {
                SObject sr = Schema.getGlobalDescribe().get(selectedObject).newSObject();
                System.debug('parsedCSV[' + i + ']' + parsedCSV[i]);

                for (Integer j = 0; j < fieldSetSObjectFields.size(); j++) {
                    SObjectField field = fieldSetSObjectFields[j];
                    System.debug('fieldset field: ' + field);
                    System.debug('value used: ' + putValue(field.type, parsedCSV[i][j]));
                    sr.put(field.developerName, putValue(field.type, parsedCSV[i][j]));
                }

                sObjectRecords.add(sr);
            }

        } catch (Exception e) {
            ApexPages.Message errorMessage = new ApexPages.Message(ApexPages.Severity.ERROR, e.getMessage());
            System.debug(LoggingLevel.ERROR, e.getMessage());
            ApexPages.addMessage(errorMessage);
        }
    }

    public void insertSObjectRecords() {
        try {
            insert sObjectRecords;
            ApexPages.Message successMessage = new ApexPages.Message(ApexPages.Severity.CONFIRM, ' Inserted ' + sObjectRecords.size() + ' ' + selectedObject + ' records!');
            ApexPages.addMessage(successMessage);

            CSVFileBody = null;
            sObjectRecords = new List<SObject>();            
        } catch (Exception e) {
            ApexPages.Message errorMessage = new ApexPages.Message(ApexPages.Severity.ERROR, e.getMessage());
            System.debug(LoggingLevel.ERROR, e.getMessage());
            ApexPages.addMessage(errorMessage);
        }
    }

    public void clearFile() {
        sObjectRecords = new List<SObject>();
        CSVFileBody = null;
    }

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
}
/**
 * Controller for ImportDataFromCSVPage to upload a CSV of records at once
 * @author Nate Helterbrand
 * @created May 2018
 */
public without sharing class ImportDataFromCSVCtrl {

    public Blob CSVFileBody {get;set;}
    public List<SObject> sObjectRecords {get;set;}
    public List<SelectOption> sObjectOptions {get; set;}
    public String selectedObject {get;set;}

    public String selectedFieldSet {get;set;}
    public List<SelectOption> fieldSetOptions {get;set;}

    public ImportDataFromCSVCtrl() {
        sObjectRecords = new List<SObject>();

        List<Schema.SObjectType> gd = Schema.getGlobalDescribe().Values();   
        sObjectOptions = new List<SelectOption>();
        
        for(Schema.SObjectType f : gd)
        {
            sObjectOptions.add(new SelectOption(f.getDescribe().getLabel(),f.getDescribe().getLabel()));
        }
    }

    public void generateFieldSetList() {
        Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
        List<Schema.FieldSet> fieldSetList = schemaMap.get(selectedObject).getDescribe().fieldsets.getMap().values();
        fieldSetOptions = new List<SelectOption>(); 

        for (Schema.FieldSet fs : fieldSetList) {
            fieldSetOptions.add(new SelectOption(fs.getLabel(), fs.getLabel()));
        }
    }

    public Object putValue(Schema.DisplayType type, Object value) {
        if (value != '') {
            if (type == Schema.DisplayType.Datetime) {
                return Date.parse((String)value);
            } else if (type == Schema.DisplayType.Date) {
                return Date.parse((String)value);
            } else if (type == Schema.DisplayType.Integer) {
                return Integer.valueOf((String)value);
            } else if (type == Schema.DisplayType.Double) {
                return Decimal.valueOf((String)value);
            } else if (type == Schema.DisplayType.Currency) {
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
            // List<Schema.FieldSetMember> importWorkOrderFieldSet = SObjectType.WorkOrder.FieldSets.Import_Work_Order_Page.getFields();

            // for (Integer i = 0; i < parsedCSV.size(); i++) {
            //     WorkOrder wo = new WorkOrder();
            //     System.debug('parsedCSV[' + i + ']' + parsedCSV[i]);

            //     for (Integer j = 0; j < importWorkOrderFieldSet.size(); j++) {
            //         Schema.FieldSetMember field = importWorkOrderFieldSet[j];
            //         System.debug('fieldset field: ' + field);
            //         System.debug('value used: ' + putValue(field.getType(), parsedCSV[i][j]));
            //         wo.put(field.getFieldPath(), putValue(field.getType(), parsedCSV[i][j]));
            //     }

            //     workOrders.add(wo);
            // }

        } catch (Exception e) {
            ApexPages.Message errorMessage = new ApexPages.Message(ApexPages.Severity.ERROR, e.getMessage());
            System.debug(LoggingLevel.ERROR, e.getMessage());
            ApexPages.addMessage(errorMessage);
        }
    }

    // public void insertWorkOrders() {
    //     try {
    //         insert workOrders;
    //         ApexPages.Message successMessage = new ApexPages.Message(ApexPages.Severity.CONFIRM, ' Inserted ' + workOrders.size() + ' Work Orders!');
    //         ApexPages.addMessage(successMessage);

    //         CSVFileBody = null;
    //         workOrders = new List<WorkOrder>();            
    //     } catch (Exception e) {
    //         ApexPages.Message errorMessage = new ApexPages.Message(ApexPages.Severity.ERROR, e.getMessage());
    //         System.debug(LoggingLevel.ERROR, e.getMessage());
    //         ApexPages.addMessage(errorMessage);
    //     }
    // }

    public void clearFile() {
        sObjectRecords = new List<SObject>();
        CSVFileBody = null;
    }

    public PageReference downloadCSVTemplate() {
        return Page.ImportDataFromCSVPageTemplateExport; 
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
/**
 * test class for import data from csv controller class
 * 
 * @author Nate Helterbrand
 * @created May 2018
 */
@isTest
private class ImportDataFromCSVCtrlTest {

    @testSetup static void setup() {
        // creating field set to use in tests

    }

    @isTest static void allFieldsInsert() {
        ImportDataFromCSVCtrl controller = new ImportDataFromCSVCtrl();
        controller.fetchSObjectOptions();
        controller.fetchFieldSetOptions();

        PageReference step2 = controller.step2();
        PageReference downloadFile = controller.downloadCSVTemplate();
        controller.clearFile();
        PageReference step1 = controller.step1();
        step2 = controller.step2();
        controller.CSVFileBody = Blob.valueOf('Name\nTest');

        Test.startTest();
        controller.transformCSVFileBodyToRecords();
        controller.insertSObjectRecords();
        Test.stopTest();
    }

    @isTest static void noFileLoaded() {
        ImportDataFromCSVCtrl controller = new ImportDataFromCSVCtrl();

        Test.startTest();
        controller.transformCSVFileBodyToRecords();
        Test.stopTest();
    }

    @isTest static void fieldSetInsert() {
        
    }
}
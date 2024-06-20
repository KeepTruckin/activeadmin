@isTest
public class QAAuditTriggerHandlerTest {
    
    @testSetup static void setupTestData() {
        
        Id adminProfId = [Select id from Profile WHERE Name=:'System Administrator'].Id;
        User adminUser = new User();
        adminUser.FirstName = 'Admin';
        adminUser.LastName = 'testUser';
        adminUser.Email = 'AdmintestUserak@test.com';
        adminUser.Username = 'AdmintestUserak@test.com';
        adminUser.ProfileId = adminProfId;
        adminUser.IsActive = true;
        adminUser.LanguageLocaleKey = 'en_US';
        adminUser.LocaleSidKey = 'en_US';
        adminUser.Alias = adminUser.FirstName.substring(0,1) + adminUser.LastName.substring(0,4);
        adminUser.EmailEncodingKey = 'UTF-8';
        adminUser.TimeZoneSidKey = 'GMT';        
        
        insert adminUser;
        
        Id stdProfId = [Select id from Profile WHERE Name=:'Standard User'].Id;
        
        User stdUser = new User();
        stdUser.FirstName = 'Admin';
        stdUser.LastName = 'testUser';
        stdUser.Email = 'stdtestUserak@test.com';
        stdUser.Username = 'stdtestUserak@test.com';
        stdUser.ProfileId = stdProfId;
        stdUser.IsActive = true;
        stdUser.LanguageLocaleKey = 'en_US';
        stdUser.LocaleSidKey = 'en_US';
        stdUser.Alias = stdUser.FirstName.substring(0,1) + stdUser.LastName.substring(0,4);
        stdUser.EmailEncodingKey = 'UTF-8';
        stdUser.TimeZoneSidKey = 'GMT';        
        
        insert stdUser;
        
        Task taskData = new Task(Priority = 'Normal',Subject = 'Test',Status = 'Scheduled', OwnerId = stdUser.Id);
        
        insert taskData;
        
		Case testCase      = new Case(Status = 'Waiting Internally', Channel__c = 'Fulfillment Support', Subject = 'TestCase2', Customer_Facing_Case__c = 'Yes');     
        insert testCase;
		
        Account acc         = new Account(Name = 'Test Account', Account_Status2__c = 'Trial');
        insert acc;
        
        QA_Audit__c objQaAudit = new QA_Audit__c();
        objQaAudit.Audited_User_Type__c = 'Billing-Ops';
        objQaAudit.Flagged_Call__c = true;
        objQaAudit.Product__c = 'Effective system usage';
        objQaAudit.Communication__c = 'Active Listening/Comprehension';
        objQaAudit.Call_Opening_Resolution__c = 'Effective probing/Identify the Issue';
        objQaAudit.Case_Hygiene__c = 'Activity not linked with Case';
        objQaAudit.Quality_Score__c = 12;
        objQaAudit.Audited_date__c = system.today();
        objQaAudit.General_Comments__c = 'test comments';
        objQaAudit.Task__c = '/'+String.valueOf(taskData.Id).substring(0, 15);
        objQaAudit.cases__c = testCase.Id;
        objQaAudit.Account__c = acc.Id;
        
        insert objQaAudit;
    }
    static testMethod void test_admin_must_be_able_to_delete_task(){

     	User adminUser = [SELECT Id FROM User WHERE Username = 'AdmintestUserak@test.com'];

        Task taskData = [SELECT Id FROM Task Where Subject = 'Test' LIMIT 1];

        System.runAs(adminUser)

        {    

            delete taskData;

        }

        try{

        	taskData = [SELECT Id FROM Task Where Subject = 'Test' LIMIT 1];

        }catch(Exception ex){

            system.assert(true);

        }       

    }   
    
}
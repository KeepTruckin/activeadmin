public class QAAuditTriggerHandler {
    
    Public static void sendEmailNotifications(Map<String,QA_Audit__c> taskIdVsQaAudit,Map<String,Task> idVsTask) {
        
        OrgWideEmailAddress owea = [SELECT Id, Address, DisplayName FROM OrgWideEmailAddress WHERE DisplayName='Motive Support' LIMIT 1];
        EmailTemplate et                                = [SELECT Id, Subject, HtmlValue FROM EmailTemplate WHERE Name ='QA Audit Assessment Notification'];
        List<Messaging.SingleEmailMessage> allmsg      = new List<Messaging.SingleEmailMessage>();
        
        for (Task taskObj : idVsTask.values()) {
            
            String taskId = String.valueOf(taskObj.Id).substring(0, 15);
            QA_Audit__c objQaAudit = taskIdVsQaAudit.get(taskId);
            if(objQaAudit != NULL) {
                String recordLink      = URL.getOrgDomainURL().toExternalForm() +'/' + objQaAudit.Id;
                String body 		   = et.HtmlValue.replace('LinkToQARecord',recordLink);
                body 				   = objQaAudit.Audited_User_Type__c != null ? body.replace('auditedUserType',objQaAudit.Audited_User_Type__c) : body.replace('auditedUserType','');
                body 				   = objQaAudit.Product__c != null ? body.replace('productOrResolution',objQaAudit.Product__c) : body.replace('productOrResolution','');
                body 				   = objQaAudit.Communication__c != null ? body.replace('communicationField',objQaAudit.Communication__c) : body.replace('communicationField','');
                body 				   = objQaAudit.Call_Opening_Resolution__c != null ? body.replace('callOpeningOrProbing',objQaAudit.Call_Opening_Resolution__c) : body.replace('callOpeningOrProbing','');
                body 				   = objQaAudit.Case_Hygiene__c != null ? body.replace('caseHygiene',objQaAudit.Case_Hygiene__c) : body.replace('caseHygiene','');
                body 				   = objQaAudit.Quality_Score__c != null ? body.replace('qualityScore',String.ValueOf(objQaAudit.Quality_Score__c)) : body.replace('qualityScore','');
                body 				   = objQaAudit.General_Comments__c != null ? body.replace('qaNotes',objQaAudit.General_Comments__c) : body.replace('qaNotes','');
                body 				   = objQaAudit.Flagged_Call__c != null ? body.replace('flaggedCall',String.ValueOf(objQaAudit.Flagged_Call__c)) : body.replace('flaggedCall','');
                body 				   = objQaAudit.Audited_date__c != null ? body.replace('auditedDates',String.ValueOf(objQaAudit.Audited_date__c)) : body.replace('auditedDates','');
                
                
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setTemplateId(et.Id);
                mail.setSubject(et.subject);
                mail.setHTMLBody(body);
                mail.toAddresses = new String[] {taskObj.owner.Email};
                    mail.setWhatId(taskObj.Id);
                mail.setSaveAsActivity(false);
                mail.setUseSignature(false);
                if (owea != null) {
                    mail.setOrgWideEmailAddressId(owea.Id);
                }
                allmsg.add(mail);
            }
            try {
                Messaging.sendEmail(allmsg,false);
            } catch (Exception e) {
                ExceptionManager.logException('QAAuditTriggerHandler.sendEmailNotifications: ' + e.getMessage() + ' | ' + e.getStackTraceString());
            }
        }
        
    }
    /*public static void sendEmailNotifications(List<v> taskLst){

EmailTemplate et                                = [SELECT Id, Subject, Body FROM EmailTemplate WHERE Name ='QA Audit Assessment'];
List<Messaging.SingleEmailMessage> allmsg       = new List<Messaging.SingleEmailMessage>();

OrgWideEmailAddress owea = [SELECT Id, Address, DisplayName FROM OrgWideEmailAddress WHERE DisplayName='Motive Support' LIMIT 1];
for(Task c : taskLst) {
List<String> toUserorGrpId = channelNamewithMembers.get(c.Channel__c);
String caseLink        = URL.getOrgDomainURL().toExternalForm() +'/' + c.Id;
String body            = et.Body.replace('{!Case.Id}',caseLink);

for(String uId : toUserorGrpId){
Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
mail.setTemplateId(et.Id);
mail.setTargetObjectId(uId);
mail.setSubject(et.subject);
mail.setHTMLBody(body);
mail.setWhatId(c.Id);
mail.setSaveAsActivity(false);
mail.setUseSignature(false);
if (owea != null) {
mail.setOrgWideEmailAddressId(owea.Id);
}
allmsg.add(mail);
}
}

try {
Messaging.sendEmail(allmsg,false);
} catch (Exception e) {
ExceptionManager.logException('CaseManager.SendEmailToQueuemember: ' + e.getMessage() + ' | ' + e.getStackTraceString());
}
}*/
}
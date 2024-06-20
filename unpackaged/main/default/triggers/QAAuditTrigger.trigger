trigger QAAuditTrigger on QA_Audit__c (after insert, after update) {
    
    if (Trigger.isAfter) {
        Set<Id> qaAuditIds = new Set<Id>();
        
        if (Trigger.isInsert || Trigger.isUpdate) {
            for(QA_Audit__c obj : Trigger.new) {
                qaAuditIds.add(obj.Id);
            }
            List<QA_Audit__c> lstQaAudit 			= [SELECT Id, Audited_User_Type__c, Flagged_Call__c, Product__c,Communication__c, Call_Opening_Resolution__c, Case_Hygiene__c, 
                                            			Quality_Score__c, Audited_date__c, General_Comments__c,Task__c FROM QA_Audit__c WHERE Id IN : qaAuditIds];
            Map<String,QA_Audit__c> taskIdVsQaAudit = new Map<String,QA_Audit__c>();
            Set<Id> relatedTaskIds				    = new Set<Id>();
            Map<String,Task> idVsTask  				= new Map<String,Task>();
            
            for(QA_Audit__c objQaAudit : lstQaAudit){
                taskIdVsQaAudit.put(objQaAudit.Task__c.replace('/',''),objQaAudit);
                relatedTaskIds.add(objQaAudit.Task__c.replace('/',''));
            }
            
            List<Task> relatedTaskList = [SELECT Id,Owner.Email FROM Task WHERE Id IN : relatedTaskIds];
            
            for(Task objTask : relatedTaskList) {
                String taskId = String.valueOf(objTask.Id).substring(0, 15);
                idVsTask.put(taskId,objTask);
            }
            
            Integer mins 			  = Integer.valueOf(System.label.QAAuditNotification_Time_Stamp);
            DateTime scheduleDateTime = system.now().addMinutes(mins);
            String scheduleDay		  = String.valueof(scheduleDateTime.day());         
            String scheduleHour		  = String.valueof(scheduleDateTime.hour());         
            String scheduleMinute	  = String.valueof(scheduleDateTime.minute());         
            String scheduleMonth	  = String.valueof(scheduleDateTime.month());         
            String scheduleYear		  = String.valueof(scheduleDateTime.year());         
            String CRON_EXPRESSION 	  = '0 '+scheduleMinute+' '+scheduleHour+' '+scheduleDay+' '+scheduleMonth+' ? '+scheduleYear; 
            String jobName 			  = 'QA Audit Notifications schedule for '+String.valueOf(scheduleDateTime);
            String jobID 			  = System.schedule(jobName, CRON_EXPRESSION, new QaAuditScheduler(taskIdVsQaAudit,idVsTask)); 
        }
        
    }
    
}
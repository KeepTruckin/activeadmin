public class QaAuditScheduler implements Schedulable {
    
    public Map<String,Task> idVsTask = new Map<String,Task>();
    public Map<String,QA_Audit__c> taskIdVsQaAudit = new Map<String,QA_Audit__c>();
    
    public QaAuditScheduler(Map<String,QA_Audit__c> taskIdVsQaAudit,Map<String,Task> idVsTask){
        this.taskIdVsQaAudit = taskIdVsQaAudit;
        this.idVsTask = idVsTask;
    }
    public void execute(SchedulableContext SC) {
        QAAuditTriggerHandler.sendEmailNotifications(taskIdVsQaAudit,idVsTask);
    }
}
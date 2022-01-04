/*
###########################################################################
# File...................: Ehf_ErrorHandler
# Version................: V1.0
# Created by.............: Coforge 
# Last Modified by.......: Coforge
# Created Date...........: 01-12-2021
# Last Modified Date.....: 01-12-2021 
# Description............: This class execute the dml operation to a sObject List, create error logs in 'Ehf_ApexErrorLog' object,
                           create a json document for the failed records while handling exception in any transaction and 
                           post on chatter for DML failed records with tagging to all admin users.
# Test Class.............: Ehf_ErrorHandlerTest
# Change Log.............: V1.0 Initial Version.
                               
#############################################################################
*/ 
public class Ehf_ErrorHandler{

    public static final String JOB_TYPE_KEYWORD = 'Worker';
    public static final String DOCUMENT_FOLDER_DEVNAME = 'Ehf_Error_Record_Documents'; 
    public static final String DOCNAME_INITIAL = 'Failed Record Json_';
    public static final String REPORT_DEVNAME = 'Ehf_ApexErrorLog_Report1';
    public static final String CHATTER_POST_BODY_MESSAGE = 'Please check attached Document and Report url of failed records.';
     
    /*
     * @author      : Coforge
     * @date        : 20-07-2021
     * @description : This method handles run type exception from async jobs and called from 'Ehf_BatchApexErrorEventsTrigger' by BatchApexErrorEvent event. 
     * @param       : List<BatchApexErrorEvent>
     * @return      : void
    */
    public static void handleRunTimeException(List<BatchApexErrorEvent> events) {
        
        List<Ehf_ApexErrorLog__c> errorsList = new List<Ehf_ApexErrorLog__c>();
        Map<id, BatchApexErrorEvent> jobIdNBatchApexJobMap = new Map<id, BatchApexErrorEvent>();
        for(BatchApexErrorEvent evt : events){
            jobIdNBatchApexJobMap.put(evt.AsyncApexJobId, evt);
        }
        
        for(AsyncApexJob asyncJob : [SELECT ApexClassId,ApexClass.Name,CompletedDate,CreatedBy.Name,CreatedById,CreatedDate,
                                    Id,JobItemsProcessed,JobType,MethodName,NumberOfErrors,ParentJobId,Status,TotalJobItems
                                    from AsyncApexJob where Id IN : jobIdNBatchApexJobMap.keySet()]){

            Id recordId = Id.valueOf(jobIdNBatchApexJobMap.get(asyncJob.Id).JobScope.SubStringBefore(','));
            String sObjName = recordId.getSObjectType().getDescribe().getName();
            String jobType = asyncJob.JobType;
            if(jobType.contains(JOB_TYPE_KEYWORD)){
                jobType = jobType.subStringBefore(JOB_TYPE_KEYWORD);
            } 
            //Create Error logs for Run Time Exceptions
            errorsList.add(new Ehf_ApexErrorLog__c(Apex_JobId__c = asyncJob.ParentJobId,                                       
                                            Exception_Type__c = jobIdNBatchApexJobMap.get(asyncJob.Id).ExceptionType,
                                            Apex_Class_Name__c = asyncJob.ApexClass.Name,
                                            Job_Scope__c = jobIdNBatchApexJobMap.get(asyncJob.Id).StackTrace,
                                            Error_Message__c = jobIdNBatchApexJobMap.get(asyncJob.Id).Message,
                                            DML_Type__c = '',
                                            Record_Ids__c = jobIdNBatchApexJobMap.get(asyncJob.Id).JobScope,
                                            Job_Type__c = jobType,
                                            Object_Name__c = sObjName
                                        ));
        }       
        insert errorsList;      
    }
    
    /*
     * @author      : Coforge
     * @date        : 20-07-2021
     * @description : This method exceute the DML operation and it returns failed and success records by wrapper class 'Ehf_ErrorWrapper'. 
     * @param1      : String
     * @param2      : String
     * @param3      : List<sObject>
     * @return      : Ehf_ErrorWrapper
    */
    public static Ehf_ErrorWrapper executeDML(String jobId, String dmlType, List<sObject> sObjectList){
        
        Ehf_ErrorWrapper batchWrapperData = new Ehf_ErrorWrapper(new List<id>(), new Map<String,sObject>(),new Map<String, Ehf_ErrorWrapper.Ehf_ErrorDetailWrapper> ());
        //For Insert OR Update DML operation
        if(dmlType != '' && sObjectList.size() > 0 && (dmlType == Ehf_ErrorWrapper.INSERTVal || dmlType == Ehf_ErrorWrapper.UPDATEVal)){
            batchWrapperData = insertOrUpdateDML(dmlType, sObjectList);
        }       
       
        //For Upsert DML operation
        if(dmlType != '' && sObjectList.size() > 0 && dmlType == Ehf_ErrorWrapper.UPSERTVal){
            batchWrapperData = upsertDML(dmlType, sObjectList);
        }       
        
        //For Delete DML operation 
        if(dmlType != '' && sObjectList.size() > 0 && dmlType == Ehf_ErrorWrapper.DELETEVal){
            batchWrapperData = deleteDML(dmlType, sObjectList);
        }       
          
        if(batchWrapperData.errorRecordsMapW.size()>0){
            createErrorLogs(jobId, new list<Ehf_ErrorWrapper>{batchWrapperData}); 
        }      
        return batchWrapperData; 
    }
    /*
     * @author      : Coforge
     * @date        : 20-07-2021
     * @description : This method creates record of the failed records in 'Ehf_ApexErrorLog' object with all the information. 
     * @param1      : String
     * @param2      : List<Ehf_ErrorWrapper>
     * @param3      : List<Ehf_ErrorWrapper.Ehf_ErrorDetailWrapper>
     * @return      : void
    */   
    public static void createErrorLogs(String jobId, List<Ehf_ErrorWrapper> errorWrapperList){

        Map<String,sObject> errorRecordsMap = new Map<String,sObject>();
        Map<String, Ehf_ErrorWrapper.Ehf_ErrorDetailWrapper> errorDetailWrapperMap = new Map<String, Ehf_ErrorWrapper.Ehf_ErrorDetailWrapper>();
        
        if(errorWrapperList.size()>0){         
            for(Ehf_ErrorWrapper errorWrap : errorWrapperList){
                errorRecordsMap.putAll(errorWrap.errorRecordsMapW);
                errorDetailWrapperMap.putAll(errorWrap.errorDetailWrapperMapW);
            }
        }
        //Fetch current Async job record
        AsyncApexJob asyncJob = [SELECT ApexClassId,ApexClass.Name,CompletedDate,CreatedBy.Name,CreatedById,CreatedDate,
                                Id,JobItemsProcessed,JobType,MethodName,NumberOfErrors,ParentJobId,Status,TotalJobItems
                                FROM AsyncApexJob WHERE id = : jobId];
                           
        List<Ehf_ApexErrorLog__c> errorsList = new List<Ehf_ApexErrorLog__c>();
        
        //Create Error logs for DML Exceptions
        if(errorDetailWrapperMap.size()>0){
            Integer i=0;
            for(Ehf_ErrorWrapper.Ehf_ErrorDetailWrapper err : errorDetailWrapperMap.values()){
                
                if(errorRecordsMap.containsKey('Error'+i)){ 
                    String objectName = String.valueOf(errorRecordsMap.get('Error'+i)).SubStringBefore(':');                          
                    errorsList.add(new Ehf_ApexErrorLog__c(Apex_JobId__c = jobId,                                       
                                                Exception_Type__c = err.statusCodeW,
                                                Apex_Class_Name__c = asyncJob.ApexClass.Name,
                                                Job_Scope__c = String.valueOf(err.fieldsW),
                                                Error_Message__c = err.messageW,
                                                DML_Type__c = err.dmlTypeW,
                                                Record_Ids__c = err.recordIdW,
                                                Job_Type__c = asyncJob.JobType,
                                                Object_Name__c = objectName
                                               ));
                }
                i++;                                       
            }
        }       
        if(errorsList.size()>0){                      
            createJsonDocument(errorsList,errorRecordsMap,errorDetailWrapperMap);
        }
    }
   
    /*
     * @author      : Coforge
     * @date        : 20-07-2021
     * @description : This method creates a Json document for the failed records and attach the link of the document to 'Ehf_ApexErrorLog' object records and insert the records.
     * @param1      : List<Ehf_ApexErrorLog__c>
     * @param2      : Map<String,sObject>
     * @param3      : Map<String,Ehf_ErrorWrapper.Ehf_ErrorDetailWrapper>
     * @return      : void
    */ 
    
    public static void createJsonDocument(List<Ehf_ApexErrorLog__c> errorsList, Map<String,sObject> errorRecordsMap, Map<String,Ehf_ErrorWrapper.Ehf_ErrorDetailWrapper> errorDetailWrapperMap){
    
       try{
        Integer count = [SELECT count() FROM Ehf_ApexErrorLog__c WHERE Apex_JobId__c =: errorsList[0].Apex_JobId__c];
        Id documentId = null;
        String strBody = '';
        //String strBody = 'Total Error Records Count: '+errorRecordsMap.size() + '\n\n';
        for(integer i = 0;i<errorRecordsMap.size();i++){           
            if(errorDetailWrapperMap.containsKey('Error'+i) && errorRecordsMap.containsKey('Error'+i)){
                strBody += 'Error '+(String.valueOf(count+i+1))+': '+errorDetailWrapperMap.get('Error'+i).messageW +'\nRecord '+(String.valueOf(count+i+1))+': '+errorRecordsMap.get('Error'+i) + ' \n\n';
            }
        }
        //Fetch existing document;
        String documentName = DOCNAME_INITIAL + errorsList[0].Apex_JobId__c;
        list<Document> existingDocument = [SELECT Id,Name,Body FROM document WHERE Name =: documentName];       
        
        if(existingDocument.size()>0){ 
            string docBody = existingDocument[0].body.tostring();
            docBody = EncodingUtil.base64Decode(EncodingUtil.base64Encode(existingDocument[0].body)).toString();
            docBody =  docBody + strBody;       
            existingDocument[0].body = Blob.valueOf(docBody);
            documentId = existingDocument[0].Id;
            update existingDocument;
        }else{                
            //Create new Document to 'Ehf_Error Record Documents' folder
            List<Folder> folderList = [SELECT Id,DeveloperName FROM folder where DeveloperName =: DOCUMENT_FOLDER_DEVNAME];
            
            Document doc = new Document();
            doc.Name = DOCNAME_INITIAL + errorsList[0].Apex_JobId__c;
            doc.Body = Blob.valueOf(strBody);
            doc.ContentType = 'text/plain';
            doc.Type = 'doc';
            doc.Description = 'Job Type: '+errorsList[0].Job_Type__c+ ', Class Name: '+errorsList[0].Apex_Class_Name__c +', Job Id: '+errorsList[0].Apex_JobId__c;
            doc.FolderId = folderList[0].Id;
            doc.IsPublic = true;
            Insert doc;
            documentId = doc.Id;           
        }
 
        for(Ehf_ApexErrorLog__c err : errorsList){
            err.Error_Record_Document_Url__c = URL.getSalesforceBaseUrl().getHost()+'/'+documentId;            
        }
        insert errorsList;    
        
       }catch(Exception ex){
            system.debug(ex.getLineNumber()+'--Exception in createJsonDocument--'+ex);
       }
      
    } 
    /*
     * @author      : Coforge
     * @date        : 20-07-2021
     * @description : This method post on chatter, link the document url of DML failed records and tag post to all the admin users. 
     * @param       : String
     * @return      : void
    */
    public static void postOnChatterNTagToAdmins(String jobId){
        
        list<Ehf_ApexErrorLog__c> errorLogsList = [select id,Apex_JobId__c from Ehf_ApexErrorLog__c where Apex_JobId__c =: jobId and DML_Type__c != ''];
        if(errorLogsList.size()>0){

            ConnectApi.FeedItemInput feedItemInput = new ConnectApi.FeedItemInput();
            ConnectApi.MessageBodyInput messageBodyInput = new ConnectApi.MessageBodyInput();
            ConnectApi.TextSegmentInput textSegmentInput = new ConnectApi.TextSegmentInput();             
            messageBodyInput.messageSegments = new List<ConnectApi.MessageSegmentInput>();
            
            //Fetch document Id and Attach document url to chatter post
            String documentName = DOCNAME_INITIAL + jobId;
            Id documentId = [SELECT Id,Name,Body FROM document WHERE Name =: documentName].Id;
                
            ConnectApi.LinkCapabilityInput linkInput = new ConnectApi.LinkCapabilityInput();
            linkInput.url = URL.getSalesforceBaseUrl().getHost()+'/'+documentId;
            linkInput.urlName = documentName;
            ConnectApi.FeedElementCapabilitiesInput feedElementCapabilitiesInput = new ConnectApi.FeedElementCapabilitiesInput();
            feedElementCapabilitiesInput.link = linkInput;
            feedItemInput.capabilities = feedElementCapabilitiesInput;
                
            String chatterPostBody = CHATTER_POST_BODY_MESSAGE + '\n Async JobId: '+jobId+'\n';                           
            textSegmentInput.text = chatterPostBody;
            messageBodyInput.messageSegments.add(textSegmentInput);
            if(!Test.isRunningTest()){
             //Fetch 'Ehf_ApexErrorLog_Report' repot and Link to Chatter body post
            Report report_Ehf = [SELECT id,name,DeveloperName FROM Report where DeveloperName =: REPORT_DEVNAME];
            ConnectApi.LinkSegmentinput linksegment = new ConnectApi.LinkSegmentinput();
            linksegment.url = 'Report Url: '+ URL.getSalesforceBaseUrl().getHost()+'/'+ report_Ehf.Id + '\n';
            messageBodyInput.messageSegments.add(linksegment);                    
            
            //Fetch all admin users and Tag to all them
            List<ApexEmailNotification> emailUserList = [SELECT UserId, User.Email, Email FROM ApexEmailNotification];
            if(emailUserList.size()>0){
                for(ApexEmailNotification emailUser : emailUserList){                   
                    ConnectApi.MentionSegmentInput mentionSegmentInput = new ConnectApi.MentionSegmentInput();
                    mentionSegmentInput.id = emailUser.UserId;
                    messageBodyInput.messageSegments.add(mentionSegmentInput);              
                }
            }else{
                ConnectApi.MentionSegmentInput mentionSegmentInput = new ConnectApi.MentionSegmentInput();
                mentionSegmentInput.id = userinfo.getuserid();
                messageBodyInput.messageSegments.add(mentionSegmentInput);  
            }
            
            feedItemInput.feedElementType = ConnectApi.FeedElementType.FeedItem;
            feedItemInput.subjectId = Userinfo.getUserId();
            feedItemInput.body = messageBodyInput;
            //Post on chatter
            ConnectApi.FeedElement feedElement = ConnectApi.ChatterFeeds.postFeedElement(Network.getNetworkId(), feedItemInput);
            }
        }
    }
    //For Insert OR Update DML
    public static Ehf_ErrorWrapper insertOrUpdateDML(String dmlType, List<sObject> sObjectList){
        
        Integer globalCount=0;
        list<id> successIdList= new list<id>();
        Map<String,sObject> errorRecordsMap= new Map<String,sObject>();
        Map<String, Ehf_ErrorWrapper.Ehf_ErrorDetailWrapper> errorDetailWrapperMap = new Map<String, Ehf_ErrorWrapper.Ehf_ErrorDetailWrapper>();           
      
        Database.SaveResult [] resultInsertOrUpdateList; 
        if(dmlType == Ehf_ErrorWrapper.INSERTVal){
            resultInsertOrUpdateList = Database.insert(sObjectList, false); 
        }else if(dmlType == Ehf_ErrorWrapper.UPDATEVal){
            resultInsertOrUpdateList = Database.update(sObjectList, false);    
        }
        for(Integer count=0;count<resultInsertOrUpdateList.size();count++){
            if (resultInsertOrUpdateList.get(count).isSuccess()){
                successIdList.add(sObjectList[count].Id);
            }else{
                Database.Error error = resultInsertOrUpdateList.get(count).getErrors().get(0);                   
                errorRecordsMap.put('Error'+globalCount,sObjectList[count]);
                Ehf_ErrorWrapper.Ehf_ErrorDetailWrapper errorDetailWrap = new Ehf_ErrorWrapper.Ehf_ErrorDetailWrapper(error.getFields(),error.getMessage(),String.valueOf(error.getStatusCode()),dmlType,sObjectList[count].Id,'');
                errorDetailWrapperMap.put('Error'+globalCount,errorDetailWrap);
                globalCount = globalCount + 1;
            }
        }        
        
        Ehf_ErrorWrapper batchWrapperData = new Ehf_ErrorWrapper(successIdList,errorRecordsMap,errorDetailWrapperMap);
        return batchWrapperData;
    }
    //For Upsert DML
    public static Ehf_ErrorWrapper upsertDML(String dmlType, List<sObject> sObjectList){
        
        Integer globalCount=0;
        list<id> successIdList= new list<id>();
        Map<String,sObject> errorRecordsMap= new Map<String,sObject>();
        Map<String, Ehf_ErrorWrapper.Ehf_ErrorDetailWrapper> errorDetailWrapperMap = new Map<String, Ehf_ErrorWrapper.Ehf_ErrorDetailWrapper>();           
        
        Database.UpsertResult [] resultUpsertList = Database.upsert(sObjectList, false);         
        for(Integer count=0;count<resultUpsertList.size();count++){
            if (resultUpsertList.get(count).isSuccess()){
                successIdList.add(sObjectList[count].Id);
            }else{
                Database.Error error = resultUpsertList.get(count).getErrors().get(0);                   
                errorRecordsMap.put('Error'+globalCount,sObjectList[count]);
                Ehf_ErrorWrapper.Ehf_ErrorDetailWrapper errorWrap = new Ehf_ErrorWrapper.Ehf_ErrorDetailWrapper(error.getFields(),error.getMessage(),String.valueOf(error.getStatusCode()),dmlType,sObjectList[count].Id,'');
                errorDetailWrapperMap.put('Error'+globalCount,errorWrap);
                globalCount = globalCount + 1;
            }
        }            
        
        Ehf_ErrorWrapper batchWrapperData = new Ehf_ErrorWrapper(successIdList,errorRecordsMap,errorDetailWrapperMap);
        return batchWrapperData;
    }
    //For Delete DML
    public static Ehf_ErrorWrapper deleteDML(String dmlType, List<sObject> sObjectList){
                
        Integer globalCount=0;
        list<id> successIdList= new list<id>();
        Map<String,sObject> errorRecordsMap= new Map<String,sObject>();
        Map<String, Ehf_ErrorWrapper.Ehf_ErrorDetailWrapper> errorDetailWrapperMap = new Map<String, Ehf_ErrorWrapper.Ehf_ErrorDetailWrapper>();           
        
        Database.DeleteResult [] resultDeleteList = Database.delete(sObjectList, false); 
        for(Integer count=0;count<resultDeleteList.size();count++){
            if (resultDeleteList.get(count).isSuccess()){
                successIdList.add(sObjectList[count].Id);
            }else{
                Database.Error error = resultDeleteList.get(count).getErrors().get(0);                   
                errorRecordsMap.put('Error'+globalCount,sObjectList[count]);
                Ehf_ErrorWrapper.Ehf_ErrorDetailWrapper errorWrap = new Ehf_ErrorWrapper.Ehf_ErrorDetailWrapper(error.getFields(),error.getMessage(),String.valueOf(error.getStatusCode()),dmlType,sObjectList[count].Id,'');
                errorDetailWrapperMap.put('Error'+globalCount,errorWrap);
                globalCount = globalCount + 1;
            }
        }
        
        Ehf_ErrorWrapper batchWrapperData = new Ehf_ErrorWrapper(successIdList,errorRecordsMap,errorDetailWrapperMap);
        return batchWrapperData;        
    }         
 
}
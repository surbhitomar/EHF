/*
###########################################################################
# File...................: Ehf_ErrorWrapper
# Version................: V1.0
# Created by.............: Coforge 
# Created Date...........: 01-12-2021
# Description............: This Error wrapper class store the failed records information while handling exception in any transaction
# Last Modified by.......: Coforge
# Last Modified Date.....: 01-12-2021
# Change Log.............: V1.0 Initial Version.
                               
#############################################################################
*/
public class Ehf_ErrorWrapper{

    //DML operation type    
    public static final String INSERTVal = 'Insert';
    public static final String UPDATEVal = 'Update';
    public static final String DELETEVal = 'Delete';
    public static final String UPSERTVal = 'Upsert';
    
    //Variables for Constructor   
    public List<id> successIdListW = new List<id>();
    public Map<String,sObject> errorRecordsMapW = new Map<String,sObject>();
    public Map<String, Ehf_ErrorWrapper.Ehf_ErrorDetailWrapper> errorDetailWrapperMapW = new Map<String, Ehf_ErrorWrapper.Ehf_ErrorDetailWrapper>();          
       
    public Ehf_ErrorWrapper(List<id> successIdList, Map<String,sObject> errorRecordsMap,Map<String, Ehf_ErrorWrapper.Ehf_ErrorDetailWrapper> errorDetailWrapperMap){
        
        successIdListW = successIdList;
        errorRecordsMapW = errorRecordsMap;
        errorDetailWrapperMapW = errorDetailWrapperMap;       
    } 
      
    public class Ehf_ErrorDetailWrapper{

        //Variables for constructor for storing exception detail
        public String[] fieldsW;
        public String messageW;
        public String statusCodeW;
        public String dmlTypeW;
        public Id recordIdW = null;
        public String lineNumberW = '';
       
       public Ehf_ErrorDetailWrapper(String[] fields,String message,String statusCode,String dmlType, Id recordId, String lineNumber){
           fieldsW = fields;
           messageW = message;
           statusCodeW = statusCode;
           dmlTypeW = dmlType; 
           recordIdW = recordId;
           lineNumberW = lineNumber;
                     
       } 
    }   
}

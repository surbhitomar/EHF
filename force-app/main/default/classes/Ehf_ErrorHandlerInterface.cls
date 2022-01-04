/*
###########################################################################
# File...................: Ehf_ErrorHandlerInterface
# Version................: V1.0
# Created by.............: Coforge 
# Last Modified by.......: Coforge
# Created Date...........: 01-12-2021 
# Last Modified Date.....: 01-12-2021
# Description............: An interface that defines the Error handler Exception framework with two method declaration,
                           and implement this interface to allow the framework to handle exception.
# Change Log.............: V1.0 Initial Version.
                               
#############################################################################
*/
public interface Ehf_ErrorHandlerInterface extends Database.RaisesPlatformEvents{
   
    /*
     * @author      : Coforge
     * @date        : 20-07-2021
     * @description : This method exceute the DML operation and it returns failed and success records by wrapper class 'Ehf_ErrorWrapper'. 
     * @param1      : String
     * @param2      : String
     * @param3      : List<sObject>
     * @return      : Ehf_ErrorWrapper
    */
    Ehf_ErrorWrapper executeDML_I(String jobId, String dmlType, List<sObject> sObjectList); 
    /*
     * @author      : Coforge
     * @date        : 20-07-2021
     * @description : This method post on chatter, link the document url of DML failed records and tag post to all the admin users. 
     * @param1      : String
     * @return      : void
    */
    void postOnChatterNTagToAdmins_I(String jobId);  
}
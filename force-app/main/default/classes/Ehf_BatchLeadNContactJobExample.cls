/**
 * Example job demonstrating the Ehf_ErrorHandlerInterface framework
   Id batchJobId = Database.executeBatch(new Ehf_BatchLeadNContactJobExample(), 200);
   //Create one validation rule as well as per your need for DML Exception
 **/
public class Ehf_BatchLeadNContactJobExample implements Database.Batchable<SObject>, Ehf_ErrorHandlerInterface
{
    public Database.QueryLocator start(Database.BatchableContext bc){
        system.debug('--start--');
        String leadStatus = 'Working - Contacted'; 
        String query = 'select Id, firstname, lastname, Email, LeadSource from Lead where createddate = THIS_WEEK'; 
               query += ' AND Status =: leadStatus order by createddate';
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<Lead> leadList) {
       
        system.debug('--execute--');
        List<Contact> contactList = new List<Contact>();
        system.debug(leadList.size()+'--leadList--->'+leadList);
        
        for(Lead leadVar : leadList) {
            system.debug('--leadVar.firstName-->'+leadVar.firstName);
            Contact contactVar = new Contact();
            contactVar.firstName = leadVar.firstName;
            contactVar.LastName = leadVar.LastName;
            //Run Time Exception
            if(leadVar.LastName == 'Limit Department'){           
                contactVar.Department = 'Hello jhjkjhjhjhjkhkjhjhkjhkjhjhhkhj mhk dakdhajkdhkjahdjkahdkjahjka   khkjhkjhkj'; 
            }else{
                contactVar.Department = leadVar.LeadSource;
            }
            if(leadVar.LastName == 'Wrong Email Check'){ 
                contactVar.Email = 'abc';
            }else{
                contactVar.Email = leadVar.Email;
            }
            
            contactList.add(contactVar);
                     
        }
        //Insert
        executeDML_I(bc.getJobId(), Ehf_ErrorWrapper.INSERTVal, contactList);
        
        //Update 
        for(Lead leadVar : leadList) {
             if(leadVar.LastName == 'Wrong Email Check'){ 
                leadVar.Email = 'abc';
            }
            if(leadVar.LastName == 'AnnualRevenue'){
                leadVar.Jigsaw = 'abc hkjhk kjhkhk khl l ji u uuouiuiuuuiyyttreewwrewrewrerwwrewew';
            }
        }
        executeDML_I(bc.getJobId(), Ehf_ErrorWrapper.UPDATEVal, leadList);
        //Upsert 
        lead lead2 = new lead(firstname='firstNAme',lastname='lastname',email='ac',company='hello',
                             leadsource='Web', Status = 'Working - Contacted');
        for(Lead leadVar : leadList) {
             if(leadVar.LastName == 'Wrong Email Check'){ 
                leadVar.Email = 'abc222';
            }          
        }
        leadList.add(lead2);
        executeDML_I(bc.getJobId(), Ehf_ErrorWrapper.UPSERTVal, leadList);
        //Delete
        list<contact> conList = [select id from contact where lastname= 'Correct'];
        executeDML_I(bc.getJobId(), Ehf_ErrorWrapper.DELETEVal, conList);
             
    }
    
    public void finish(Database.BatchableContext bc) { 
        system.debug('--finish--');
        postOnChatterNTagToAdmins_I(bc.getJobId());
    }
    
    //'Ehf_ErrorHandlerInterface' Interface method definition 
    
    public static Ehf_ErrorWrapper executeDML_I(String jobId, String dmlType, List<sObject> sObjectList) {      
        Ehf_ErrorWrapper errorWrapper= Ehf_ErrorHandler.executeDML(jobId, dmlType, sObjectList);    
        return errorWrapper;   
    } 
    public static void postOnChatterNTagToAdmins_I(String jobId){
            Ehf_ErrorHandler.postOnChatterNTagToAdmins(jobId);    
    }


   
}
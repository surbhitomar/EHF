/**
###########################################################################
# File...................: Ehf_BatchApexErrorEventsTrigger
# Version................: V1.0
# Created by.............: Coforge 
# Last Modified by.......: Coforge
# Created Date...........: 01-12-2021 
# Last Modified Date.....: 01-12-2021
# Description............: This trigger Subscribes to BatchApexErrorEvent standard platform events
# Test Class.............: Ehf_ErrorHandlerTest
# Change Log.............: V1.0 Initial Version.
                               
#############################################################################
**/ 
trigger Ehf_BatchApexErrorEventsTrigger on BatchApexErrorEvent (after insert) {

    Ehf_ErrorHandler.handleRunTimeException(Trigger.new);    
}
public class MyContactListController {

  
    public static List<Contact> getContacts() {
        return [Select Id, Name, Email, Title, Phone From Contact];
    }
    
    public static List<Lead> getLeads() {
        return [Select Id, Name, Email, Title, Phone From Lead];
    }
    
    public static List<Adam_Bar__c> getAdams() {
        return [Select Id, Name From Adam_Bar__c];
    }
    
    static void myBar() {
        Adam_Bar__c newBar = new Adam_Bar__c(Name='My New Bar');
        insert newBar;
    }
    
    public static void applyDiscount(Adam_Bar__c[] books) {
      for (Adam_Bar__c b :books){
         b.Name = 'fred';
      }
   }
    
}
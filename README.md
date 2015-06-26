# CallGirl
Generic CRUD 5 model rails ui skeleton for use as a starting point for other rails applications. Nested with has_many&lt;->belongs_to relationships between each section. 

Each 
*list -> has_many: members

*member -> has_many :components

*component -> has_many: modules

*module -> has_many: attributes 

*attribute -> has_many: details

*detail -> has_many: statistics
 
 ** TODO **
 
 consider has_and_belongs_to_many or other associations
 

# CallGirl Pre-v0.1.0
pre v.01 before adding models from system and adminlte
Generic CRUD 5 model rails ui skeleton for use as a starting point for other rails applications. Nested with has_many&lt;->belongs_to relationships between each section. 

## Gems
Jquery
Bootstrap3

## Database Support
Mysql2 -> Working!
Mongo/Mongoid
Redis

Each:

*list -> has_many: members

*member -> has_many :components

*component -> has_many: modules

*module -> has_many: attributes 

*attribute -> has_many: details

*detail -> has_many: statistics
 
 ** TODO **
 
 consider has_and_belongs_to_many or other associations
 

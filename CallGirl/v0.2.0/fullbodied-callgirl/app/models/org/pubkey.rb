module Org
class Pubkey < ActiveRecord::Base
	belongs_to :user
	belongs_to :machine
	belongs_to :server

end
end

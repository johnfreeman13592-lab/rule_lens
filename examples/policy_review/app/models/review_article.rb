class ReviewArticle < ActiveRecord::Base
  belongs_to :author, class_name: "ReviewUser"
end

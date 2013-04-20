class HomepageController < ApplicationController
	skip_before_filter :verify_authenticity_token
	@@data = Rails.root.to_s+'/input.json'


	def postcomments
		render :nothing => true
		tmp_file = "#{Rails.root}/out.txt"
		File.open(tmp_file, 'wb') do |f|
			f.write params[:commentInfos]
		end
	end

	def input
		#render :json => @data, :callback =>params[:callback]
		send_file(@@data,
  			:filename => "input",
  			:type => "application/json")
	end
end

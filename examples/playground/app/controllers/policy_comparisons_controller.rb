class PolicyComparisonsController < ApplicationController
  def show
    @version = params.fetch(:version, "buggy")
    unless BlogDemo::VERSIONS.key?(@version)
      @error = "比較する変更を一覧から選んでください。"
      @version = "buggy"
      return render :show, status: :unprocessable_entity
    end

    @report = BlogDemo.compare(@version)
  end
end

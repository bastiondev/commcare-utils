class HomeController < ApplicationController

  before_action :require_user!

  def index
    redirect_to destinations_path
  end

end
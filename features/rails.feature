Feature: Using skywriter in a rails app

  Scenario: Skywriter in some flash messages in the controller
    Given I save the following as "app/controllers/users_controller.rb"
    """
    class UsersController < ActionController::Base
      def index
        flash[:success] = s(".controller-test", :default => "default")
      end
    end
    """
    And I save the following as "config/routes.rb"
    """
    ActionController::Routing::Routes.draw do |map|
      map.resources :users
    end
    """
    And I save the following as "app/views/users/index.html.erb"
    """
    <%= flash[:success] %>
    """
    And this plugin is available
    And the rails app is running
    When I visit /users/
    Then I should see "e:production b:users.index.controller-test"

  Scenario: Skywriter in some flash messages in the view
    Given I save the following as "app/controllers/users_controller.rb"
    """
    class UsersController < ActionController::Base
      def index
        render :action => "index"
      end
    end
    """
    And I save the following as "config/routes.rb"
    """
    ActionController::Routing::Routes.draw do |map|
      map.resources :users
    end
    """
    And I save the following as "app/views/users/index.html.erb"
    """
    <%= s(".view-test", :default => "default") %>
    """
    And this plugin is available
    And the rails app is running
    When I visit /users/
    Then I should see "e:production b:users.index.view-test"


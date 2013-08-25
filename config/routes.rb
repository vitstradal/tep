Pia::Application.routes.draw do
  devise_for :users

  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  #resources  :sosna_problems
  get  '/sosna/problem(/:id)'     => 'sosna#problem',           :as => :sosna_problem
  get  '/sosna/problems'          => 'sosna#problems'
  post '/sosna/problem_save'      => 'sosna#problem_save',      :as => :sosna_problem_save
  get  '/sosna/solutions'         => 'sosna#solutions',         :as => :sosna_solutions
  get  '/sosna/schools'           => 'sosna#schools',           :as => :sosna_schools
  post '/sosna/solution_save'     => 'sosna#solution_save',     :as => :sosna_solution_save
  get  '/sosna/application'       => 'sosna#application',       :as => :sosna_application
  get  '/sosna/application/tnx'   => 'sosna#application_tnx',   :as => :sosna_application_tnx
  post '/sosna/application/submit'=> 'sosna#application_submit',:as => :sosna_application_submit
  get  '/sosna/config'            => 'sosna#get_config',        :as => :sosna_config
  post '/sosna/config/save'       => 'sosna#config_save',       :as => :sosna_config_save

  get  '/users'                   => 'pia#users',               :as => :users_list
  post '/user/:id'                => 'pia#user_edit',           :as => :user_edit
  post '/user/:id/role'           => 'pia#role_change',         :as => :user_role_change

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  root :to => "pia#index"

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  match ':controller(/:action(/:id(.:format)))'
end

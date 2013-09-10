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

  # přidání akcí je třeba přidat i práva v app/models/ability.rb

  # anon:
  get  '/sosna/solver/new'         => 'sosna_solver#new',         :as => :sosna_solver_new
  post '/sosna/solver/create'      => 'sosna_solver#create',      :as => :sosna_solver_anon_create
  get  '/sosna/solver/tnx'         => 'sosna_solver#create_tnx',  :as => :sosna_solver_create_tnx

  # user:
  get  '/sosna/solutions'          => 'sosna_solution#user_index',   :as => :sosna_user_solutions
  post '/sosna/solution/update'    => 'sosna_solution#user_upload',  :as => :sosna_user_solution_update
  put  '/sosna/solution/update'    => 'sosna_solution#user_upload',  :as => :sosna_user_solution_update
  get  '/sosna/solution/:id/down'  => 'sosna_solution#download',     :as => :sosna_user_solution_down

  # org:
  get  '/sosna/orgsolutions'       => 'sosna_solution#index',        :as => :sosna_org_solutions
  get  '/sosna/orgsolution(/:id)'  => 'sosna_solution#show',         :as => :sosna_org_solution
  post '/sosna/orgsolution/update' => 'sosna_solution#update',       :as => :sosna_org_solution_update

  get  '/sosna/problems'           => 'sosna_problem#index',         :as => :sosna_problems
  get  '/sosna/problem(/:id)'      => 'sosna_problem#show',          :as => :sosna_problem
  post '/sosna/problem/update'     => 'sosna_problem#update',        :as => :sosna_problem_update
  put  '/sosna/problem/update'     => 'sosna_problem#update',        :as => :sosna_problem_update

  get  '/sosna/solvers'         => 'sosna_solver#index',       :as => :sosna_solvers
  get  '/sosna/solver(/:id)'    => 'sosna_solver#show',        :as => :sosna_solver
  post '/sosna/solver/update'   => 'sosna_solver#update',      :as => :sosna_solver_update

  get  '/sosna/schools'            => 'sosna_school#index',          :as => :sosna_schools
  post '/sosna/school/update'      => 'sosna_school#update',         :as => :sosna_school_update

  get  '/sosna/config'             => 'sosna_config#index',          :as => :sosna_configs
  post '/sosna/config/update'      => 'sosna_config#updateall',      :as => :sosna_config_updateall

  # pia
  get  '/users'                   => 'pia#users',                    :as => :users_list
  put  '/user/role'               => 'pia#user_role_change',         :as => :user_role_change

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
end

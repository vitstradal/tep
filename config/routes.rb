Pia::Application.routes.draw do
  devise_for :users


  # přidání akcí je třeba přidat i práva v app/models/ability.rb
  # anon:
  get  '/sosna/solver/new'         => 'sosna_solver#new',            :as => :sosna_solver_new
  post '/sosna/solver/create'      => 'sosna_solver#create',         :as => :sosna_solver_anon_create
  get  '/sosna/solver/tnx'         => 'sosna_solver#create_tnx',     :as => :sosna_solver_create_tnx

  # user:
  get  '/sosna/solutions/user'     => 'sosna_solution#user_index',   :as => :sosna_solutions_user
  post '/sosna/solution/upload'    => 'sosna_solution#upload',       :as => :sosna_solution_upload
  put  '/sosna/solution/upload'    => 'sosna_solution#upload',       :as => :sosna_solution_upload
  get  '/sosna/solution/:id/down'  => 'sosna_solution#download',     :as => :sosna_solution_download

  # org:
  #get  '/sosna/solutions/org'      => 'sosna_solution#index',        :as => :sosna_solutions_org
  get  '/sosna/solutions(/:roc(/:se(/:ul)))'=> 'sosna_solution#index',:as => :sosna_solutions_org
  get  '/sosna/solutions/:roc/:se/:ul/edit'=>'sosna_solution#edit',   :as => :sosna_solutions_edit
  post '/sosna/solutions/update_scores' =>'sosna_solution#update_scores',:as => :sosna_solutions_update_scores
  post '/sosna/solution/update'    => 'sosna_solution#update',       :as => :sosna_solution_update
  get  '/sosna/solution/downall'   => 'sosna_solution#downall',      :as => :sosna_solution_update
  get  '/sosna/solution(/:id)'     => 'sosna_solution#show',         :as => :sosna_solution

  get  '/sosna/problems'           => 'sosna_problem#index',         :as => :sosna_problems
  get  '/sosna/problem(/:id)'      => 'sosna_problem#show',          :as => :sosna_problem
  post '/sosna/problem/update'     => 'sosna_problem#update',        :as => :sosna_problem_update
  put  '/sosna/problem/update'     => 'sosna_problem#update',        :as => :sosna_problem_update
  post '/sosna/problem/new_round'  => 'sosna_problem#new_round',     :as => :sosna_problem_new_round

  get  '/sosna/solvers'         => 'sosna_solver#index',             :as => :sosna_solvers
  get  '/sosna/solver(/:id)'    => 'sosna_solver#show',              :as => :sosna_solver
  post '/sosna/solver/update'   => 'sosna_solver#update',            :as => :sosna_solver_update
  put  '/sosna/solver/update'   => 'sosna_solver#update',            :as => :sosna_solver_update

  get  '/sosna/schools'            => 'sosna_school#index',          :as => :sosna_schools
  post '/sosna/school/update'      => 'sosna_school#update',         :as => :sosna_school_update

  get  '/sosna/config'             => 'sosna_config#index',          :as => :sosna_configs
  post '/sosna/config/update'      => 'sosna_config#update',         :as => :sosna_config_update

  # pia
  get  '/users'                   => 'pia#users',                    :as => :users_list
  put  '/user/role'               => 'pia#user_role_change',         :as => :user_role_change

  get  '/wiki(/:path)'             => 'giwi#show',                   :as =>  :wiki, constrains: { path: /.*/ }, defaults: {wiki: :main}
  post '/wiki(/:path)'               => 'giwi#update',                 :as =>  :wiki_post, constrains: { path: /.*/ }, defaults: {wiki: :main}

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  root :to => "pia#index", :as => :root

  # See how all your routes lay out with "rake routes"
end

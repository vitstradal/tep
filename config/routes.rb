# encoding: utf-8
Pia::Application.routes.draw do

  devise_for :users


  # přidání akcí je třeba přidat i práva v app/models/ability.rb
  # anon:
  get  '/sosna/solver/new'         => 'sosna/solver#new',            :as => :sosna_solver_new
  post '/sosna/solver/create'      => 'sosna/solver#create',         :as => :sosna_solver_anon_create
  get  '/sosna/solver/tnx'         => 'sosna/solver#create_tnx',     :as => :sosna_solver_create_tnx

  # user:
  get  '/sosna/solutions/user(/:roc(/:se))'  => 'sosna/solution#user_index', :as => :sosna_solutions_user
  patch '/sosna/solution/upload'     => 'sosna/solution#upload',     :as => :sosna_solution_upload
  post '/sosna/solution/upload_corr' => 'sosna/solution#upload_corr',:as => :sosna_solution_upload_corr
  get  '/sosna/solution/:id/down'  => 'sosna/solution#download',     :as => :sosna_solution_download
  get  '/sosna/solution/:id/down_corr'  => 'sosna/solution#download_corr',:as => :sosna_solution_download_corr

  # org:
  #get  '/sosna/solutions/org'      => 'sosna/solution#index',        :as => :sosna_solutions_org
  get  '/sosna/solutions(/:roc(/:se(/:ul)))'=> 'sosna/solution#index',:as => :sosna_solutions_org
  get  '/sosna/solutions/:roc/:se/:ul/edit'=>'sosna/solution#edit',   :as => :sosna_solutions_edit
  post '/sosna/solutions/update_scores' =>'sosna/solution#update_scores',:as => :sosna_solutions_update_scores
  post '/sosna/solution/update'    => 'sosna/solution#update',       :as => :sosna_solution_update
  get  '/sosna/solution/downall'   => 'sosna/solution#downall',      :as => :sosna_solution_down
#  get  '/sosna/solution(/:id)'     => 'sosna/solution#show',         :as => :sosna_solution

  get  '/sosna/problems'           => 'sosna/problem#index',         :as => :sosna_problems
  get  '/sosna/problem(/:id)'      => 'sosna/problem#show',          :as => :sosna_problem
  patch '/sosna/problem/update'     => 'sosna/problem#update',       :as => :sosna_problem_update
  post '/sosna/problem/new_round'  => 'sosna/problem#new_round',    :as => :sosna_problem_new_round

  get  '/sosna/solvers'         => 'sosna/solver#index',             :as => :sosna_solvers
  get  '/sosna/solver(/:id)'    => 'sosna/solver#show',              :as => :sosna_solver
  patch '/sosna/solver/update'   => 'sosna/solver#update',           :as => :sosna_solver_update
  post '/sosna/solver/:id/delete'   => 'sosna/solver#delete',           :as => :sosna_solver_delete

  get  '/sosna/schools'            => 'sosna/school#index',          :as => :sosna_schools
  get  '/sosna/school/new'         => 'sosna/school#new',            :as => :sosna_school_new
  get  '/sosna/school/:id/show'    => 'sosna/school#show',           :as => :sosna_school
  patch '/sosna/school/update'  => 'sosna/school#update',            :as => :sosna_school_update
  post  '/sosna/school/update'  => 'sosna/school#update',            :as => :sosna_school_updateP
  post '/sosna/school/:id/delete'   => 'sosna/school#delete',           :as => :sosna_school_delete

  get  '/sosna/config'             => 'sosna/config#index',          :as => :sosna_configs
  post '/sosna/config/update'      => 'sosna/config#update',         :as => :sosna_config_update

  # pia
  get  '/users'                   => 'pia#users',                    :as => :users_list
  patch '/user/role'               => 'pia#user_role_change',         :as => :user_role_change
  get  '/reg/:token'               => 'pia#user_finish_registration',         :as => :user_finish_registration

  get  '/wiki(/*path)'             => 'giwi#show',                   :as =>  :wiki, constrains: { path: /.*/ }, defaults: {wiki: :main}
  post '/wiki(/*path)'               => 'giwi#update',                 :as =>  :wiki_post, constrains: { path: /.*/ }, defaults: {wiki: :main}

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  get  '/faq'                        => "pia#faq",                   :as => :faq
  root :to => "pia#index", :as => :root

  # See how all your routes lay out with "rake routes"
end

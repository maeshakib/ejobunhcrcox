<?php

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use App\Permission;
use Faker\Factory as Faker;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     *
     * @return void
     */
    public function run()
    {

   
    
        // Role comes before User seeder here.
        //$this->call(RoleTableSeeder::class);
        // $now = date("Y-m-d H:i:s");
        // DB::table('location_levels')->insert([
        //     ['id' => 1, 'name' => 'Country', 'created_at' => $now],
        //     ['id' => 2, 'name' => 'Division', 'created_at' => $now],
        //     ['id' => 3, 'name' => 'District', 'created_at' => $now],
        //     ['id' => 4, 'name' => 'Upzilla', 'created_at' => $now],
        //     ['id' => 5, 'name' => 'Union', 'created_at' => $now],
        //     ['id' => 6, 'name' => 'Block', 'created_at' => $now],
        //     ['id' => 7, 'name' => 'Group', 'created_at' => $now]
            
//         ]);

//         DB::table('location_areas')->insert([
//             ['id' => 1,'name' => 'Bangladesh', 'parent_id' => 0, 'location_level_id' => 1, 'created_at' => $now]
            
//         ]);

//         DB::table('roles')->insert([
//             ['id' => 1,'name' => 'Super Admin', 'description' => 'Super Power', 'status' => 1, 'is_deletable' => 0, 'created_at' => $now],
         
            
//         ]);

//         DB::table('designations')->insert([
//             ['id' => 1,'name' => 'GM', 'description' => 'General Manager', 'created_at' => $now],
         
            
//         ]);
//         DB::table('departments')->insert([
//             ['id' => 1,'name' => 'Marketing', 'description' => 'Marketing department', 'created_at' => $now]
            
//         ]);

//         DB::table('users')->insert([
//             ['id' => 1,'name' => 'user1', 'email' => 'user1@user1.com', 
//             'password' => bcrypt('secret'), 'role_id' => 1, 'created_at' => $now,
//             'designation_id' => 1,'department_id'=> 1, 'location_area_id' => 1]
            
//         ]);
       
//         //permission seeder 
//         $allRoutes=Route::getRoutes();
//         //dd($allRoutes);
//          $controllers =array();
//          foreach ($allRoutes as $route){
//           $action = $route->getAction();
//           if (array_key_exists('controller', $action)){
//            $controllerAction =explode('@', $action['controller']);
//            $controllers[class_basename($controllerAction[0])][$controllerAction[1]]=$controllerAction[1];
//           }
//          }

//         // permission not need for this following controlles
//          unset($controllers['UserLoginController']);

//          //dd($controllers);
//          foreach($controllers as $key=>$controller){
//            $data['name']=$key;
//            $parent=Permission::firstOrCreate($data);
//            if($parent){
//             $data2['parent_id']=$parent->id;
//             foreach($controller as $elements){
//               $data2['name']=$elements;
//               $all_done = Permission::firstOrCreate($data2);
//              }
//            }
//           }
//         //end permission seeder


// //role_permission seeder
//           $permissions= Permission::all();
//           foreach ($permissions as $value) 
//           {          
//               DB::table('role_permissions')->insert([
//                 ['role_id' => 1,'permission_id' => $value->id]

//             ]);

//           }  




    }
}

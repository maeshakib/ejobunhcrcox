<?php
namespace App\Http\Controllers;


use App\Role;
use App\Permission;
use App\RolePermission;
use App\User;
use Validator;
use Redirect;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Route;
use DB;
class RoleController extends Controller
{
  
    public function index()
    {
        $roles = Role::orderBy('description')->select('id','name','description','status','is_deletable')->get();		
        return response()->json($roles,200);
    }

  
    public function create()
    {
        
        //create permission
        $this->createRolePermission();
        $data = Permission::with('children')->where('parent_id', null)->get();
        return response()->json($data, 200);
    }

    private function createRolePermission()
    {
        $allRoutes = Route::getRoutes();
        // return response()->json($allRoutes , 200);

        $controllers = array();
        foreach ($allRoutes as $route) {
            $action = $route->getAction();
            if (array_key_exists('controller', $action)) {
                $controllerAction = explode('@', $action['controller']);
                $controllers[class_basename($controllerAction[0])][$controllerAction[1]] = $controllerAction[1];
            }
        }

        // permission not need for this following controlles
        unset($controllers['UserLoginController']);

        foreach ($controllers as $key => $controller) {

            $data['name'] = $key;
            $parent = Permission::firstOrCreate($data);
            if ($parent) {
                   
                $data2['parent_id'] = $parent->id;
                foreach ($controller as $elements) {
                    $data2['name'] = $elements;
                    $all_done = Permission::firstOrCreate($data2);
                }
            }
        }

    }

    public function store(Request $request)
	{
		//rules
		$rules = array(
			'name'       => 'required|unique:roles',
			'description' => 'required',
			'is_deletable' => [
				'required',
				Rule::in([0, 1]),
			],
			'permissions' => 'required|array|min:1'
		);
		//message
		$messages=array(
			'name.required|unique:roles,name' => 'Please enter Name',
			'permissions.required' => 'Role Must Have Atleast 1 Permission'
		); 
		//validator        
		$validator = Validator::make($request->all(), $rules, $messages);

		if($validator->fails())
		{
			$returnMessage = array(
				'success' => false,
				'error' => $validator->errors()
			
			);
			return response()->json($returnMessage, 200);
		}

		//new Role creation
		$role = new Role;
		$role->name =$request->name; 
		$role->description = $request->description;
		$role->is_deletable = $request->is_deletable;

		$saved = $role->save();
		//permisssion start here
		if($saved)
		{
			$permission_data = array();
			foreach($request['permissions'] as $data_one)
			{
				$permission_data[] =
				[
					'role_id' =>$role->id,
					'permission_id' => $data_one,
				]; 														
				
			}	
			RolePermission::insert($permission_data);
			$data['success']=true;
			$data['data']=$role;
			return response()->json($data);

		}
		
		$returnMessage = array(
			'success' => false,
			'error'       => 'Not Saved!!'
		
		);
        return response()->json($returnMessage, 200);
		
	
	}


    public function show($id)
	{
		$role=Role::find($id);
		//$permissions=Permission::with('children')->whereNull('parent_id')->orderBy('name')->get()->toArray();
		//$checkPermissions=RolePermission::with('Permission')->where('role_id',$id)->pluck('permission_id')->toArray();
        return response()->json($role, 200);
	}
    public function edit($id)
    {

        $all_data = [];
        $roles = Role::findorfail($id);

        $menus = DB::table('permissions')
            ->leftjoin('role_permissions', function ($join) use ($id) {
                $join->on('role_permissions.permission_id', '=', 'permissions.id');
                $join->where('role_permissions.role_id', $id);
            })
            ->select('permissions.id', 'permissions.name', 'role_permissions.permission_id as permission_id', 'permissions.parent_id')->get();

        $parents = $menus->where('parent_id', null)->values();

        foreach ($parents as $parent) {
            $data[$parent->name] = $parent;
            $data[$parent->name]->child = $menus->where('parent_id', $parent->id)->values();

        }

        //all roles data
        $all_data['roles'] = $roles;
        //all data with role with permission
        $all_data['data'] = $data;
        //Response::json($data)

        return $all_data;
        // return $obj;

    }

    public function update(Request $request, $id)
    {
        //rules
        $rules = array(
            'name' => [
                'required',
                Rule::unique('roles')->ignore($id),
            ],
            'description' => 'required',
            'is_deletable' => [
                'required',
                Rule::in([0, 1]),
            ],
            'permissions' => 'required|array|min:1',
        );
        //message
        $messages = array(
            'name.required' => 'Please enter Name',
            'permissions.required' => 'Role Must Have Atleast 1 Permission',

        );
        //validator
        $validator = Validator::make($request->all(), $rules, $messages);

        if ($validator->fails()) {
            $returnMessage = array(
                'success' => false,
                'error' => $validator->errors(),

            );
            return response()->json($returnMessage, 406);
        }

        $request_data = request()->only('name', 'description', 'is_deletable');

        //dd($data);
        $permissions = request()->get('permissions');
        if (!isset($permissions)) {$permissions = array();}
        $Role = Role::find($id);
        //$Role->fill($request_data);
        $Role->name = $request->name;
        $Role->description = $request->description;
        $Role->is_deletable = $request->is_deletable;
        $Role->save();
        $Role->permissions()->sync($permissions);
        if ($Role) {
            $returnMessage = array(
                'success' => true,
                'message' => 'Updated!!',

            );
            return response()->json($returnMessage, 200);

        }

    }

    public function destroy(Request $request, $id)
    {
        $rules = array(
            'role_id' => 'required|exists:roles,id|not_in:' . $id,
        );
        //message
        $messages = array(
            'role_id.required' => 'Please Select a Role',
        );
        //validator
        $validator = Validator::make($request->all(), $rules, $messages);

        if ($validator->fails()) {
            $returnMessage = array(
                'success' => false,
                'error' => $validator->errors(),
            );
            return response()->json($returnMessage, 406);
        }

        $role = Role::find($id);
        if ($role->is_deletable == 0) {
            $returnMessage = array(
                'success' => false,
                'error' => 'This Role Cannot be Deleted!!',
            );
            return response()->json($returnMessage, 406);
        }
        $data = request()->only('role_id');
        //return $data;
        $applyed = User::where('role_id', $id)->update($data);
        $permissionDelete = RolePermission::where('role_id', $id)->delete();
        $deleted = Role::destroy($id);
        if ($deleted) {
            $returnMessage = array(
                'success' => true,
                'message' => 'Role Deleted',
            );
            return response()->json($returnMessage, 200);
        }

        $returnMessage = array(
            'success' => false,
            'error' => $validator->errors(),

        );
        return response()->json($returnMessage, 406);

    }
//end destroy function

}

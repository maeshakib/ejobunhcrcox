<?php
 /*
    *****************************************************
                         README
    *****************************************************
     Author       :OneICT
     Editor       :amimul ehasan shakib
     Checked by   :Raju, Sahadat
     File Version :F.20

    ****************************************************
    
     */



namespace App\Http\Controllers;
use JWTAuth;

use DB;
use App\User;
use App\Role;
use App\Depot;
use Validator;
use App\RolePermission;
use App\LocationLevel;
use App\LocationArea;
use App\Designation;
use App\Department;
use Illuminate\Validation\Rule;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use App\Http\Controllers\Controller;
use Illuminate\Support\Carbon;

class AdminController extends Controller
{

    public function __construct()
    {
        $this->middleware('auth:api', ['except' => ['login','register']]);
       
               
    }
    //Submit create user form with data
    public function store(Request $request)
    {
        //return $request->all();

        $rules = array(
            'name' => 'required',
            'email' => 'required|email|unique:users',
            'password' => 'required',
            'mobile_no' => 'required',
            'location_area_id' => 'required',
            'join_date' => 'required',
            'designation_id' => 'required',
            'role_id' => 'required',
            'supervisor_id' => 'required',
          
         
        );

        $messages=array(
            'name.required' => 'Please enter Name',
            'email.required' => 'Please enter Email',
            'password.required' => 'Please enter Password',
            'mobile_no.required' => 'Please enter Mobile',
            'location_area_id.required' => 'Please Select Location',
            'join_date.required' => 'Please Select Join Date',
            'designation_id.required' => 'Please Select Designation',
            'role_id.required' => 'Please Select Role',
            'supervisor_id.required' => 'Please Select Supervisor',
    
            
        ); 

        $validator = Validator::make($request->all(), $rules, $messages);

        if($validator->fails())
        {
            $returnMessage = array(
                'success' => false,
                'errors' => $validator->errors(),
                );
            return response()->json($returnMessage, 406);
        }
        $user = new User();
        $user->name = $request->name;
        $user->email = $request->email;
        $user->password = bcrypt($request->password);
        $user->role_id = $request->role_id;
        $user->designation_id = $request->designation_id; 
        $user->department_id = $request->department_id; 
        $user->gender = $request->gender;
        $user->mobile_no = $request->mobile_no;
        $user->location_area_id = $request->location_area_id;
        $user->national_identification_num = $request->national_identification_num;
        $user->join_date = $request->join_date;
        $user->is_supervisor = $request->is_supervisor;
        $user->supervisor_id = $request->supervisor_id;
        $user->description = $request->description;
        $user->address = $request->address;
        if($request->has('status'))
        {
            $user->status = $request->status;
            
        }else{
            $user->status = 1;
        }
        if ($request->hasFile('photo')) {
            $image = $request->file('photo');
            $name =  'Profle_photo_'.time().'.'.$request->photo->getClientOriginalExtension();
            $destinationPath = public_path('/img/user');
            $imagePath = $destinationPath. "/".  $name;
            $image->move($destinationPath, $name);
            $user->photo = "/img/user/".$name;
            
        }

        $saved = $user->save();

     

        if($saved)
        {
            return response()->json(['success' => true, 'message' =>'Saved Successfully'], 200); 
        }else{
            return response()->json(['success' => false, 'message' =>'Oops!!'], 200);
        }

      
    } //end function

   
//display create user form with all designations and roll data
    public function create()
    {        
        $user = auth('api')->user();

        $data['roles']=Role::all(['id','name']);
        $data['designations']=Designation::all(['id','name']);
        $data['departments']=Department::all(['id','name']);
        $data['depots']=Depot::all(['id','name']);
        $data['supervisors']=User::with(['department:id,name','designation:id,name','location_area:id,name,location_level_id'])
        ->where('is_supervisor',1)
       // ->where('id','!=',$user->id)
      
        ->get(['id', 'name','department_id','designation_id','location_area_id']);
         $data['levels'] = LocationLevel::where('id',1)->get(['id', 'name']);

        if($data['levels']->count()>0)
        {
            foreach ($data['levels'] as $d) 
            {
                $d['loclist']=[];
            }
            $data['levels']['0']['loclist'] = LocationArea::where('parent_id', 0)->orderBy('name')->get(['id', 'name']);                     
        }

        return response()->json($data,200); 

    }

    public function index(Request $request)
    {

        $rules = array(
            'status' => 'required'
        );
        $messages=array(
            'status.required' => 'Please enter a status.'
        );
        $validator = Validator::make($request->all(), $rules, $messages);
        if($validator->fails())
        {
            $returnMessage = array(
            'success' => false,
            'errors' => $validator->errors(),
            );
            return response()->json($returnMessage, 403);
        }
      
      //return $request->status;
      if($request->status== 2){
        $users=User::with('role:id,name,status,is_deletable','designation:id,name','department:id,name', 'my_manager')
        ->select('id','name','email','role_id','join_date','mobile_no','photo','designation_id','department_id','supervisor_id','gender','is_supervisor','status')->whereIn('status',[0,1])->get();
        return response()->json($users,200);
    }else{
        $users=User::with('role:id,name,status,is_deletable','designation:id,name','department:id,name','my_manager')
        ->select('id','name','email','role_id','join_date','mobile_no','photo','designation_id','department_id','supervisor_id','gender','is_supervisor','status')->where('status',$request->status)->get();
        return response()->json($users,200);
    }
    
    }

    public function edit($id)
    {
        $data=array();
        $data['user']=User::with('role','designation','department','location_area','depot')->where('id',$id)->first();
     
        $area_id=$data['user']->location_area_id;
        $data ['selected_location']= DB::select('SELECT T2.id as selected_loc_id, T2.name,T2.parent_id, T2.location_level_id
        FROM (
            SELECT
                @r AS _id,
                (SELECT @r := parent_id FROM location_areas WHERE id = _id) AS parent2_id,
                @l := @l + 1 AS lvl
            FROM
                (SELECT @r := ?, @l := 0) vars,
                location_areas m
            WHERE @r <> 0) T1
        JOIN location_areas T2
        ON T1._id = T2.id
        ORDER BY T1.lvl DESC',[$area_id]);

        return response()->json($data,200);
       //return response()->json($users,200);
    }

    public function destroy(Request $request,$id)
    {
       // return $request->all();
        $rules = array(
            'user_id' => 'required|exists:users,id|not_in:' . $id,
        );
        //message
        $messages = array(
            'user_id.required' => 'Please Select a User',
        );
        //validator
        $validator = Validator::make($request->all(), $rules, $messages);

        if ($validator->fails()) {
            $returnMessage = array(
                'success' => false,
                'error' => $validator->errors(),
            );
            return response()->json($returnMessage, 200);
        }

//get employees list   

     $updaterec = User::where('supervisor_id', '=', $id)->update(['supervisor_id' => $request->user_id]);
     $user = User::find($id);

        if($user){
            $user->status=2;
            $user->deleted_at=now();
            $user->save();
            return response()->json(['success' => true, 'message' =>'Deleted Successfully'], 200); 
        }
        return response()->json(['success' => false, 'error' =>'User Not Found'], 200); 


    }



    protected function update(Request $request, $id)
    {
       //return $request->all();
        $rules = array(
            'name' => 'required',
            'email' => [
				'required',
				Rule::unique('users')->ignore($id),
			],
            'photo' => 'image|mimes:jpeg,bmp,png|max:1024',
            'role_id' => 'required|exists:roles,id',
            'mobile_no' => 'required|digits:11',
            'designation_id' => 'required|exists:designations,id',
            'join_date' => 'required|date',
            'location_area_id' => 'required|exists:location_areas,id',

            'supervisor_id' => 'required|exists:users,id',
            'is_supervisor' => 'required|digits_between:0,1',
            'status' => 'required|digits_between:0,1'
        );

        $messages=array(
            'name.required' => 'Please enter Name',
            'email.required' => 'Please enter Email',
            'role_id.required' => 'Please Select Role',
            'mobile_no.required' => 'Please enter Mobile',
            'mobile_no.digits' => 'Please enter 11 digit',
            'join_date.required' => 'Please Select Join Date',
            'designation_id.required' => 'Please Select Designation',
            'location_area_id.required' => 'Please Select Location',
            'supervisor_id.required' => 'Please Select Supervisor',
            'status.required' => 'Please Select status',
        ); 

        $validator = Validator::make($request->all(), $rules, $messages);
        if($validator->fails())
        {
            $returnMessage = array(
                'success' => false,
                'errors' => $validator->errors(),
                );
            return response()->json($returnMessage, 406);
        }
    
        $user = User::find($id);          
        $user->name = $request->name;
        $user->email = $request->email;
        $user->role_id = $request->role_id;
        $user->designation_id = $request->designation_id; 
        $user->department_id = $request->department_id; 
        $user->gender = $request->gender;
        $user->mobile_no = $request->mobile_no;
        $user->location_area_id = $request->location_area_id;
        $user->national_identification_num = $request->national_identification_num;
        $user->join_date = $request->join_date;
        $user->supervisor_id = $request->supervisor_id;
        $user->description = $request->description;
        $user->address = $request->address;
        $user->status = $request->status;
        if($request->has('depot_id') && $request->depot_id){
            $user->depot_id = $request->depot_id;

        }
        $user->is_supervisor = $request->is_supervisor;

        if ($request->hasFile('photo')) {
            $image = $request->file('photo');
            $name =  'Profle_photo_'.time().'.'.$request->photo->getClientOriginalExtension();
            $destinationPath = public_path('/img/user');
            $imagePath = $destinationPath. "/".  $name;
            $image->move($destinationPath, $name);
            $user->photo = "/img/user/".$name;
            
        }
        $saved = $user->save();
        if($saved)
        {
            return response()->json(['success' => true, 'message' =>'Update Successfully'], 200); 
        }

        return response()->json(['success' => false, 'message' =>'Oops!!'], 200);

    } //end function
 
//admin login start here
public function login(Request $request)
{
    $credentials = $request->only('email', 'password');
    $rules = [
        'email' => 'required|email',
        'password' => 'required',
    ];
    $validator = Validator::make($credentials, $rules);
    if($validator->fails()) {
        return response()->json([
            'success' => false,
            'errors' => $validator->errors(),
        ]);
    }
    try {
        // Attempt to verify the credentials and create a token for the user
        if (! $token = JWTAuth::attempt($credentials)) {
            return response()->json([
                'success' => false, 
                'error' => 'We can`t find an account with this credentials.'
            ], 200);
        }
    } catch (JWTException $e) {
        // Something went wrong with JWT Auth.
        return response()->json([
            'success' => false, 
            'errors' => $e->errors()
        ], 200);
    }
    // All good so return the token
    return $this->respondWithToken($token);
   
}




protected function respondWithToken($token)
{
   //get current user id
   $user = Auth::user();


   $user_role_perse_int=$user->role_id;
   $menus = DB::table('permissions')
        ->leftjoin('role_permissions', function ($join) use($user_role_perse_int) {
           $join->on('role_permissions.permission_id', '=' , 'permissions.id') ;
           $join->where('role_permissions.role_id',$user_role_perse_int) ;
       })
       ->select('permissions.id','permissions.name',
        DB::raw('cast(ifnull(role_permissions.permission_id, 0) as integer) as permission_id'),
        DB::raw('cast(ifnull(permissions.parent_id, 0) as integer) as parent_id'))->get();

   $parents = $menus->where('parent_id', null)->values();
   
   foreach ($parents as $parent) 
   {
       $data[$parent->name]= $parent;
       $data[$parent->name]->child = $menus->where('parent_id', $parent->id)->values();
   }





    //response 
    return response()->json([
        'success' => true,
        'message' =>'Saved Successfully',
        'access_token' => $token,
        'token_type' => 'bearer',
        'expires_in' => auth('api')->factory()->getTTL() * 10000000,            
        'raw_data' => $data,
       
      
    ]);
 
}
//admin login end here

}
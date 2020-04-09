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
use Mail;
use App\Mail\SendMail;
use DB;
use App\User;
use Validator;

use Illuminate\Validation\Rule;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use App\Http\Controllers\Controller;

class UserLoginController extends Controller
{

    public function __construct()
    {
        $this->middleware('auth:api', ['except' => ['login','register','signup','send']]);
       
               
    }
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
        // All good so
        // return the token
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
            'u_id' => $user->id,
           
          
        ]);
     
    }


    public function userPermissionListData()
    {
        $user = auth('api')->user();
        $user_role_perse_int=$user->role_id;
        $menus = DB::table('permissions')
             ->leftjoin('role_permissions', function ($join) use($user_role_perse_int) {
                $join->on('role_permissions.permission_id', '=' , 'permissions.id') ;
                $join->where('role_permissions.role_id',$user_role_perse_int) ;
            })
            ->select('permissions.id','permissions.name','role_permissions.permission_id as permission_id','permissions.parent_id')->get();
 
        $parents = $menus->where('parent_id', null)->values();
        
        foreach ($parents as $parent) 
        {
            $data[$parent->name]= $parent;
            $data[$parent->name]->child = $menus->where('parent_id', $parent->id)->values();
        }
   
        return response()->json([  
            'raw_data' => $data,
            'user_name' => $user->name,
            'user_email' => $user->email
            ]);
    }


    public function logout()
    {

// Pass true to force the token to be blacklisted "forever"
auth()->logout(true);
        
    }


    public function myProfile()
    {
        $user = auth('api')->user();
        $profile = user::with([
            'role:id,name',
            'designation:id,name',
            'department:id,name',
            'location_area:id,name,location_level_id',
            'my_manager:id,name',
            'location_area.location_levels:id,name',
            
            // 'my_employees' => function($query){
            //     $query->select(['id','name', 'supervisor_id']);
            // }
                        ])
                        ->where('id', $user->id)
                        ->first();
        return response()->json($profile, 200);
    }


    protected function profileUpdate(Request $request)
    {
        $rules = array(
            'name' => 'required',
            'photo' => 'image|mimes:jpeg,bmp,png|max:1024',
            'mobile_no' => 'required|digits:11',
            'national_identification_num' => 'required',
           
        );

        $messages=array(
            'name.required' => 'Please enter Name',
            'mobile_no.required' => 'Please enter Mobile',
            'national_identification_num.required' => 'Please enter NID',
        ); 

        $validator = Validator::make($request->all(), $rules, $messages);

        if($validator->fails())
        {
            $returnMessage = array(
                'success' => false,
                'errors' => $validator->errors(),
                );
            return response()->json($returnMessage, 200);
        }
    
        $user = auth('api')->user();
        
        $userProfile = User::find($user->id);
        $userProfile->name= $request->name;
        $userProfile->mobile_no= $request->mobile_no;
        $userProfile->national_identification_num= $request->national_identification_num;
        $userProfile->description= $request->description;
        $userProfile->address= $request->address;
      //  $userProfile->fill($request->only(['name', 'description', 'national_identification_num', 'mobile_no', 'gender', 'address']));
        
        // if ($request->hasFile('photo')) {
        //     $image = $request->file('photo');
        //     $name =  'Profle_photo_'.time().'.'.$request->photo->getClientOriginalExtension();
        //     $destinationPath = public_path('/img/user');
        //     $imagePath = $destinationPath. "/".  $name;
        //     $image->move($destinationPath, $name);
        //     $userProfile->photo = "/img/user/".$name;
            
        // }

        $saved = $userProfile->save();
        if($user)
        {
            return response()->json(['success' => true, 'message' =>'Saved Successfully'], 200); 
        }

        return response()->json(['success' => false, 'message' =>'Oops!!'], 200);

    }

    public function send(Request $request)
    {
        //if user with mail id authentic then create otp save otop to db and send mail with otp
        //       
       
        $user_check = User::where('email',$request->input('email'))->firstOrFail();
        if (!$user_check) 
        {
            return response()->json([
                'success' => false,
                'message' => 'Sorry, User with email ' . $request->input('email') . ' cannot be found'
            ], 400);
        }else
        {

            Mail::to($request->input('email'))->send(new SendMail($this->otp()));
            return response()->json(['success' => false, 'message' =>'Email sent successfully. Check your email'], 200);
    
        }
     

    }

    public function resetPassword($token)
    {
        $checkToken = User::where('reset_token','=',$token);

        if (!$checkToken) 
        {
            return response()->json([
                'success' => false,
                'message' => 'Sorry, Invalid Reset Link'
            ], 400);
        }else
        {
            return response()->json([
                'success' => true,
                'message' => 'OK'
            ], 200);
        }

    }

    public function setNewPassword()
    {
        $rules = array(
            'email' => 'required|exists:clients,email',
            'password' => 'required',
      
            
        );
        $messages=array(
            'email.required' => 'Please enter a Email.',
            'password.required' => 'Please enter a Password.',
         
        );
       

        $validator = Validator::make($request->all(), $rules, $messages);

        if($validator->fails())
        {
            $returnMessage = array(
            'success' => false,
            'errors' => $validator->errors(),
            );
            return response()->json(['success' => true, 200]);
        }
    }
//user signup function start
  //Submit create user form with data
  public function signup(Request $request)
  {
      //return $request->all();

      $rules = array(
          'name' => 'required',
          'email' => 'required|email|unique:users',
          'password' => 'required',
          'mobile_no' => 'required',              
      );

      $messages=array(
          'name.required' => 'Please enter Name',
          'email.required' => 'Please enter Email',
          'password.required' => 'Please enter Password',
          'mobile_no.required' => 'Please enter Mobile',     
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
      $user->role_id =5;
      $user->gender = $request->gender;   

      $saved = $user->save();

   

      if($saved)
      {
          return response()->json(['success' => true, 'message' =>'Saved Successfully'], 200); 
      }else{
          return response()->json(['success' => false, 'message' =>'Oops!!'], 200);
      }

    
  } //end function

//user signup function end
private function otp($length = 4) 
    {
            $characters = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
            $charactersLength = strlen($characters);
            $randomString = '';
            for ($i = 0; $i < $length; $i++) {
                $randomString .= $characters[rand(0, $charactersLength - 1)];
            }
            return $randomString;
    }
}
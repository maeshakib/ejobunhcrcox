<?php

namespace App\Http\Middleware;

use App\Permission;
use App\RolePermission;
use Closure;
use Route;

class UserAccess
{
    /**
     * Handle an incoming request.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  \Closure  $next
     * @return mixed
     */
    public function handle($request, Closure $next)
    {

        // Get the currently authenticated user
        $user = auth('api')->user();
        if(!$user){
            $returnMessage['original'] = array(
              'success' => false,
              'errors' => 'User Not Authorised!!',
              );
              return response()->json($returnMessage,200);
          }
        // Get the currently authenticated user
        $controllerAction = class_basename(Route::currentRouteAction());

        if (isset($controllerAction)) 
        {
            list($current_location['controller'], $current_location['action']) = explode('@', $controllerAction);

            $pid = Permission::where('name', $current_location['controller'])->pluck('id');

            if (count($pid) > 0) 
            {
                $check = RolePermission::where('role_id', $user->role_id)->where('permission_id', function ($query) use ($current_location, $pid, $controllerAction) {
                    $query->select('id')
                        ->from('permissions')
                        ->where('name', $current_location['action'])
                        ->where('parent_id', $pid);
                })->get();

                if (count($check) > 0) 
                {
                    $response = $next($request);
                    return response()->json($response, 200);
                } else 
                {

                    //App::abort(404, 'Not Allowed');
                    $returnMessage['original'] = array(
                        'success' => false,
                        'errors' => 'User Does Not Have Permission',
                    );
                    return response()->json($returnMessage, 200);

                }
            } else 
            {
                //App::abort(404, 'Not Allowed');
                $returnMessage['original'] = array(
                    'success' => false,
                    'errors' => 'User Does Not Have Permission',
                );
                return response()->json($returnMessage, 200);
            }
        }


        
      

    } // end handle function
}

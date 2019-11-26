<?php

namespace App\Http\Controllers;

use DB;
use Validator;
use App\LocationLevel;
use App\LocationArea;
use App\MessengerGroup;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Support\Collection;

class LocationAreaController extends Controller
{
   /**
    Version      :v.1
    T-Code       :d-t-mvc:1-10-10-1-10
    Description  : display paginated LocationArea data
    */
    public function index()
    {
        $locations = LocationArea::paginate(5);
        return response()->json($locations, 200);
        //return $locations;
    }

    /**
    Version      :v.1
    T-Code       :d-t-mvc:1-10-10-2-10
    Description  : save a new location area
    */
    public function store(Request $request)
    {
        //return $request->all();
        if($request->has('parent_id'))
            $parent = $request->parent_id;
        else{
            $msg = array('parent_id' => 'parent is required.');
            return $msg;
        }
            
        $rules = array(
            //'name'       => 'required|max:190',
            'location_level_id' => 'required',
            'parent_id' => 'required',
            'kmlfile' => 'file',
            'lat_lng' => 'present',
            'name' => [
                'required',
                Rule::unique('location_areas')->where(function ($query) use($parent) {
                return $query->where('parent_id', $parent);
            })
            ]
            
        );
    //return 'ok';
        $messages=array(
            'name.required' => 'Please enter a Name.',
            
        );
        $validator = Validator::make($request->all(), $rules, $messages);
        if($validator->fails())
        {
            $returnMessage = array(
            'success' => false,
            'errors' => $validator->errors(),
            'message'       => 'Oops!!'
            
            );
            return response()->json($returnMessage, 403);
        }
        //return $request->all();
        if ($request->hasFile('kmlfile')) {
            $kml = $request->file('kmlfile');
            $name =  'KML_for_'.$request->name.'_'.time().'.'.$request->kmlfile->getClientOriginalExtension();
            $destinationPath = public_path('/kml');
            $kml->move($destinationPath, $name);
            $path = "/kml/".$name;
            $request->request->add(['map_data' => $path]);
            
        }
        $location = new LocationArea($request->only(['location_level_id', 'parent_id', 'map_data', 'lat_lng', 'name']));
        $location->save();
       
        $returnMessage = array(
            'success' => true,
            'message'       => 'Saved Successfully!!'
            
        );
        return response()->json($returnMessage, 201);
    }

    /**
    Version      :v.1
    T-Code       :d-t-mvc:1-10-10-3-10
    Description  : display specific location area
    */
    public function show($id)
    {
        $location = LocationArea::with('allChildren')->find($id);
        return response()->json($location, 201);
    }

    /**
    Version      :v.1
    T-Code       :d-t-mvc:1-10-10-4-10
    Description  : update existing location area
    */
    public function update(Request $request, $id)
    {
        // if($request->has('parent_id'))
        //     $parent = $request->parent_id;
        // else{
        //     $msg = array('parent_id' => 'parent is required.');
        //     return $msg;
        // }
        //return $request->all();
        $rules = array(
            'location_level_id' => 'required',
            'parent_id' => 'required',
            'kmlfile' => 'file',
            'lat_lng' => 'present',
            'name' => [
                'required',
                Rule::unique('location_areas')
            ->where(function ($query) use($request, $id) {
                return $query->where('parent_id', $request->parent_id);
                
            })->ignore($id)]
            
        );
        $messages=array(
            'name.required' => 'Please enter a Name.',
            
        );
        $validator = Validator::make($request->all(), $rules, $messages);
        if($validator->fails())
        {
            $returnMessage = array(
            'success' => false,
            'errors' => $validator->errors(),
            'message'       => 'Oops!!'
            
            );
            return response()->json($returnMessage, 406);
        }
     
        $location = LocationArea::find($id);
        $location->name = $request->name;
        $location->parent_id = $request->parent_id;
        $location->location_level_id = $request->location_level_id;
        $location->lat_lng = $request->lat_lng;
        $location->description = $request->description;
        if ($request->hasFile('kmlfile')) {
            $kml = $request->file('kmlfile');
            $name =  'KML_for_'.$request->name.'_'.time().'.'.$request->kmlfile->getClientOriginalExtension();
            $destinationPath = public_path('/kml');
            $kml->move($destinationPath, $name);
            $location->map_data = "/kml/".$name;  
        }
        $location->save();

        $returnMessage = array(
            'success' => true,
            'message'       => 'Updated Successfully!!'
            
        );
        return response()->json($returnMessage, 200);
    }

    /**
    Version      :v.1
    T-Code       :d-t-mvc:1-10-10-5-10
    Description  : delete a location area
    */
    public function destroy($id)
    {
        $location = LocationArea::find($id);
        if ($location) 
        {

            $child = LocationArea::where('parent_id', $id)->first();
            if($child){
                $returnMessage = array(
                    'success' => false,
                    'errors' => $location->name.' has Dependent Data!!'
                );
                return response()->json($returnMessage, 200);
            }
           
            try {
                $location->delete();
                $returnMessage = array(
                    'success' => true,
                    'message'       => 'Deleted Successfully!!'
                
                );
                return response()->json($returnMessage, 200);
            } catch (\Exception $e) {
                $returnMessage = array(
                    'success' => false,
                    'errors' => $location->name.' has Dependent Data!!'
                );
                return response()->json($returnMessage, 200);
            }
            
        }
        $returnMessage = array(
                'success' => false,
                'message'       => 'Something Went Wrong!!'
            
            );
        return response()->json($returnMessage, 404);
    }
    /**
    Version      :v.1
    T-Code       :d-t-mvc:1-10-10-6-10
    Description  : get all location level
    */
    public function levelDD()
    {
     
        $levels = LocationLevel::all(['id', 'name']);
        return response()->json($levels, 201);
    }
    /**
    Version      :v.1
    T-Code       :d-t-mvc:1-10-10-7-10
    Description  : get LocationLevel upto a specific value and get the parent LocationArea list
    */
    public function getlevel($val)
    {
        $data['levels'] = LocationLevel::where('id','<',$val)->get(['id', 'name']);
        if($data['levels']->count()>0){
            foreach ($data['levels'] as $d) {
                $d['loclist']=[];
            }
            $data['levels']['0']['loclist'] = LocationArea::where('parent_id', 0)->orderBy('name')->get(['id', 'name']);
            //$data['loclist'] = Location::where('parent_id', 0)->orderBy('name')->get(['id', 'name']);
            return response()->json($data, 201);
        }
        return response()->json($data, 201);
    }
    /**
    Version      :v.1
    T-Code       :d-t-mvc:1-10-10-8-10
    Description  : get all location of a specific parent 
    */
    public function getlocation($id)
    {
        //return $id;
        if(is_numeric($id)){
            $locations = LocationArea::where('parent_id', $id)->orderBy('name')->get(['id', 'name']);
            return response()->json($locations, 201);
        }
        return response()->json([], 403);
        
    }

    /**
    Version      :v.1
    T-Code       :d-t-mvc:1-10-10-8-10
    Description  : get all location of a specific parent 
    */
    public function getlocation_Self()
    {
        $user = auth('api')->user();
        $data['my_location_area'] = LocationArea::with('location_levels:id,name')->find($user->location_area_id);
        $data['children'] = LocationArea::where('parent_id', $user->location_area_id)->orderBy('name')->get(['id', 'name']);
        return response()->json($data, 201);
        
        //return response()->json([], 403);
        
    }

    

    /**
    Version      :v.1
    T-Code       :d-t-mvc:1-10-10-9-10
    Description  : get all location area for a specific level_id
    */
    public function getLevelwiseLocation($level_id)
    {
        $locations = LocationArea::where('location_level_id', $level_id)->orderBy('name')->get();
        //$locations['level'] = Level::find($level_id);
        $data = DB::table('location_areas')
        ->leftjoin('location_areas AS L', 'L.id', '=', 'location_areas.parent_id')
        ->where('location_areas.location_level_id', $level_id)
        ->select('location_areas.*','L.name as parent')
        ->get();
        return response()->json($data, 201);
        
    }


    /**
    Version      :v.1
    T-Code       :d-t-mvc:1-10-10-10-10
    Description  : get all location of a specific parent 
    */
    public function getlocationWithLevel($id)
    {
     $level = LocationArea::find($id, ['location_level_id']);
  
     $data = LocationLevel::where('id', '>',$level->location_level_id)->first(['id', 'name']);
   
        if($data){
            
            $data['loclist'] = LocationArea::where('parent_id', $id)->orderBy('name')->get(['id', 'name']);           
            
        }

        return response()->json($data, 201);
        
    }

    /**
    Version      :v.1
    T-Code       :d-t-mvc:1-10-10-10-10
    Description  : get all location of a specific parent 
    */
    public function getlocationWithLevel_self()
    {
        $user = auth('api')->user();
        $today = date('Y-m-d');
        $level = LocationArea::find($user->location_area_id, ['location_level_id']);
        $data['data'] = LocationLevel::where('id', '>',$level->location_level_id)->first(['id', 'name']);
        if($data){
            $data['data']['loclist'] = LocationArea::where('parent_id', $user->location_area_id)->orderBy('name')->get(['id', 'name']);           
        }
        $data['attendance'] = DB::select('SELECT ua.*, u.name, u.photo from user_attendances ua
        join users u ON ua.user_id = u.id 
        WHERE ua.user_id IN (
                select p1.id as location_id
                from        location_areas p1
                left join   location_areas p2 on p2.id = p1.parent_id 
                left join   location_areas p3 on p3.id = p2.parent_id 
                left join   location_areas p4 on p4.id = p3.parent_id  
                left join   location_areas p5 on p5.id = p4.parent_id  
                left join   location_areas p6 on p6.id = p5.parent_id
                where       :user_location in (p1.parent_id, 
                                   p2.parent_id, 
                                   p3.parent_id, 
                                   p4.parent_id, 
                                   p5.parent_id, 
                                   p6.parent_id))
               AND ua.date = :date',['date' => $today, 'user_location' => $user->location_area_id]);
        $data['success'] = true;
        return response()->json( $data, 201);
        
    }

    public function getLocationParents($id)
    {
        $data = LocationArea::find($id);
        //$data['parents'] = $parents;
        if($data)
        {
            $parents = DB::select('SELECT T2.id as selected_loc_id, T2.name,T2.parent_id, T2.location_level_id
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
            ORDER BY T1.lvl DESC',[$id]);
            array_pop($parents);
            $message = array(
                'success' => true,
                'data' => $data,
                'parents' => $parents
            );
            return response()->json($message, 200);
        }
        $message = array(
            'success' => false,
            'data' => null
        );
        return response()->json($message, 200);
        
    }


}

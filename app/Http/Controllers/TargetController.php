<?php

namespace App\Http\Controllers;

use DB;
use Validator;
use App\LocationArea;
use App\Target;
use App\User;
use Illuminate\Http\Request;
class TargetController extends Controller
{
    
    public function create()
    {
        $user = auth('api')->user();
        $employees = User::where('supervisor_id', $user->id)
        ->get(['id','name']);
        return response()->json($employees, 200);
    


      
    }

    public function getMonthListforUserTarget(Request $request)
    {
        $user = auth('api')->user();
        $rules = array(
            'user_id' => 'required|exists:users,id',
            'type' => 'required|numeric|between:0,1', // 0 = sales, 1 = collection
        );
        $messages=array(
            'user_id.required' => 'Please select a User',          
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
        $firstDate = date('Y-m-01');
        //return $now;
        $targets = Target::where('user_id', $request->user_id)
                    ->where('type', $request->type)
                    ->whereDate('from_date', '>=', $firstDate)
                    ->get()->keyBy('from_date');
        $arr = collect([]);

        for ($i=0; $i < 12; $i++) { 
            $date = new \DateTime($firstDate);
            $date->modify('+'.$i.' month');
            $assigned = false;
            if($targets->has($date->format('Y-m-d'))){
                $assigned = true;
            }
            $arr->push([
                'date' => $date->format('M-Y'), 
                'assigned' => $assigned,
                'from_date' => $date->format('Y-m-01'),
                'to_date' => $date->format('Y-m-t')]);
        }
        
        return $arr;
    
      
    }


    public function index(Request $request)
    {  
        $rules = array(
            'from_date' => 'required|date',
            'to_date' => 'required|date|after_or_equal:from_date',
        );
        $messages=array(
            'from_date.required' => 'Please select a Date.',          
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
        
        $from_date= $request->from_date;
        $date = new \DateTime($request->to_date);
        $to_date = $date->format('Y-m-t');

        //return $to_date;

        $users_with_sales_collection = User::with(['location_area:id,name',  'collections'
         => function($q) use($from_date,$to_date)
         {
             $q->whereBetween('collection_date',[$from_date,$to_date])->orderBy('collection_date','desc');
         }, 
         'sales' 
        => function($q) use($from_date,$to_date)
        {
            $q->whereBetween('sales_date',[$from_date,$to_date])->orderBy('sales_date','desc');
        }
        ])
        ->where('supervisor_id', $user->id)
        ->get(['id', 'name', 'address', 'supervisor_id', 'location_area_id', 'mobile_no', 'photo', 'status' ]);
       
        foreach ($users_with_sales_collection as $u) {
            $u['user_collection'] = $u->collections->sum('collection_amount');
            $u['user_sales'] = $u->sales->sum('sales_amount');
            unset($u['collections']);
            unset($u['sales']);
        }
        $total_target = DB::select(
            'SELECT t.type, SUM(t.target_amount) as total  FROM targets t 
                JOIN users u on t.user_id = u.id AND u.supervisor_id = :user_id
                WHERE t.from_date >= :from_date AND t.to_date <= :to_date
                GROUP by u.supervisor_id, t.type',
                ['user_id' => $user->id, 
                'from_date' => $from_date,
                'to_date' => $to_date]);

        //return $total_target;
        

        $total_collection_target = 0;
        $total_sales_target = 0;
        foreach ($total_target as $target) {
            if ($target->type == 0) {
                $total_sales_target = $target->total;
            } else {
                $total_collection_target = $target->total;
            }
        }
        
        return response()->json([
            'total_sales' => $users_with_sales_collection->sum('user_sales'),
            'total_sales_target' => $total_sales_target,
            'total_collection' => $users_with_sales_collection->sum('user_collection'),
            'total_collection_target' => $total_collection_target,
            'users' => $users_with_sales_collection
            ]  
        ,200);
        
    }

    public function selfTarget(Request $request)
    {
        $rules = array(
            'from_date' => 'required|date',
            'to_date' => 'required|date|after_or_equal:from_date',
        );
        $messages=array(
            'from_date.required' => 'Please select a Date.',          
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
        
        $from_date= $request->from_date;
        $date = new \DateTime($request->to_date);
        $to_date = $date->format('Y-m-t');
        $total_target_sub = DB::select(
            'SELECT t.type, SUM(t.target_amount) as total  FROM targets t 
                JOIN users u on t.user_id = u.id AND u.supervisor_id = :user_id
                WHERE t.from_date >= :from_date AND t.to_date <= :to_date
                GROUP by u.supervisor_id, t.type',
                ['user_id' => $user->id, 
                'from_date' => $from_date,
                'to_date' => $to_date]);
        
        $total_target = DB::select(
            'SELECT t.type, SUM(t.target_amount) as total
            FROM targets t 
                    JOIN users u on t.user_id = u.id 
                    WHERE t.from_date >= :from_date AND t.to_date <= :to_date AND u.id = :user_id
                    GROUP by t.type',
                ['user_id' => $user->id, 
                'from_date' => $from_date,
                'to_date' => $to_date]);
        $arr = array();
        $total_collection_target = 0;
        $total_sales_target = 0;
        foreach ($total_target_sub as $target) {
            if ($target->type == 0) {
                $total_sales_target = $target->total;
            } else {
                $total_collection_target = $target->total;
            }
        }
        $data = [
            'tag' => 'sub',
            'total_sales_target' => $total_sales_target,
            'total_collection_target' => $total_collection_target,
        ];
        $arr[] = $data;
        $total_collection_target = 0;
        $total_sales_target = 0;
        foreach ($total_target as $target) {
            if ($target->type == 0) {
                $total_sales_target = $target->total;
            } else {
                $total_collection_target = $target->total;
            }
        }
        $data = [
            'tag' => 'self',
            'total_sales_target' => $total_sales_target,
            'total_collection_target' => $total_collection_target,
        ];
        $arr[] = $data;
        $returndata['success'] = true; 
        $returndata['data'] = $arr; 
        return response()->json($returndata, 200);
    }

    public function userTarget(Request $request)
    {
        $rules = array(
            'from_date' => 'required|date',
            'to_date' => 'required|date|after_or_equal:from_date',
            'user_id' => 'required|exists:users,id',
        );
        $messages=array(
            'from_date.required' => 'Please select a Date.',          
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
        $from_date= $request->from_date;
        $date = new \DateTime($request->to_date);
        $to_date = $date->format('Y-m-t');
        $employee = User::with(['location_area:id,name', 'designation:id,name'])
        ->where('supervisor_id', $user->id)
        ->where('id', $request->user_id)
        ->first(['id', 'name', 'address', 'supervisor_id', 'location_area_id', 'mobile_no', 'photo', 'designation_id' ]);
        if (!$employee) {
            $returnMessage = array(
                'success' => false,
                'errors' => 'Cannot Access Employee Info',
            );
            return response()->json($returnMessage, 200);
        }
        $d =  DB::select('SELECT 
            DATE_FORMAT(from_date, "%b-%Y") as month, 
            type, 
            target_amount,
            id,
            note,
            CASE WHEN type = 0 THEN
            ifnull((SELECT sum(s.sales_amount) FROM 
                    sales s WHERE s.user_id = t.user_id AND s.sales_date BETWEEN t.from_date AND t.to_date),0)
            ELSE 0 END
            as total_sales,
            CASE WHEN type = 1 THEN
            ifnull((SELECT sum(c.collection_amount) FROM 
                    collections c WHERE c.user_id = t.user_id AND c.collection_date BETWEEN t.from_date AND t.to_date),0)
            ELSE 0 END
            as total_collection
            FROM targets t 
            WHERE user_id = :user_id AND t.from_date >= :from_date AND t.to_date <= :to_date
            ORDER BY t.from_date',
                ['user_id' => $request->user_id, 
                'from_date' => $from_date,
                'to_date' => $to_date]);
        $data = collect($d);
        $groupedData = $data->groupBy('type');
        $employee['total_sales'] = 0;
        $employee['total_sales_target'] = 0;
        $employee['total_collection'] = 0;
        $employee['total_collection_target'] = 0;
        if($groupedData->has('0')){
            $employee['total_sales'] = $groupedData['0']->sum('total_sales');
            $employee['total_sales_target'] = $groupedData['0']->sum('target_amount');
        }
        if($groupedData->has('1')){
            $employee['total_collection'] = $groupedData['1']->sum('total_collection');
            $employee['total_collection_target'] = $groupedData['1']->sum('target_amount');
        }
         
        $groupedData = $data->groupBy('month');
        $monthList = collect([]);
        foreach ($groupedData as $key => $value) {
            $obj = [
                'month' => $key,
                'sales_target' => 0,
                'collection_target' => 0,
                'total_sales' => 0,
                'total_collection' => 0,
                'sales_id' => 0,
                'collection_id' => 0,
                'sales_note' => null,
                'collection_note' => null
           
                ];
                //return $value;
            foreach ($value as $v) {
                if($v->type == 0){
                    $obj['sales_id'] = $v->id;                    
                    $obj['sales_note'] = $v->note;
                    $obj['sales_target'] = $v->target_amount;
                    $obj['total_sales'] = $v->total_sales;
                }
                if($v->type == 1){
                    $obj['collection_id'] = $v->id;
                    $obj['collection_note'] = $v->note;
                   $obj['collection_target'] = $v->target_amount;
                    $obj['total_collection'] = $v->total_collection;
                }

            }
            //return $obj;
            $monthList->push($obj);


        }
        $employee['months'] = $monthList;
        $employee['success'] = true;
        return $employee;
    }

    public function store(Request $request)
    {
        $rules = array(
            'user_id' => 'required|exists:users,id',
            'type' => 'required|numeric|between:0,1',
            'from_date' => 'unique:targets,from_date,NULL,id,type,'.$request->type.',user_id,'.$request->user_id,
            'note' => 'present',
            'to_date' => 'required|after:from_date|date',
            'target_amount' => 'required|numeric|digits_between:0,9',
        );
        $messages = array(
            'user_id.required' => 'Please enter a User.',
            'from_date.required' => 'Date Range Required',
            'to_date.required' => 'Date Range Required',
            'target_amount.required' => 'Target Amount Required',
            'target_amount.digits_between' => 'Target Amount Should Be Digits',

        );
        $validator = Validator::make($request->all(), $rules, $messages);
        if ($validator->fails()) {
            $returnMessage = array(
                'success' => false,
                'errors' => $validator->errors(),
            );
            return response()->json($returnMessage, 200);
        }
        $user = auth('api')->user();
        $Target = new Target;
        $Target->fill($request->only([
            'user_id',
            'type',
            'from_date',
            'to_date',
            'note',
            'target_amount',
        ]));
        $Target->created_by = $user->id;
        $sales_param = $Target->save();
        if ($sales_param) {
            return response()->json(['success' => true, 'message' => 'Target Saved Successfully '], 200);
        } else {
            return response()->json(['success' => false, 'message' => 'Target Information has not been Saved '], 200);
        }

    }

    public function show($id)
    {
        $target = Target::find($id);

        if (!$target) {
            return response()->json([
                'success' => false,
                'message' => 'Sorry, Target with id ' . $id . ' cannot be found',
            ], 200);
        } else {

            return response()->json([
                'success' => true,
                'target' => $target,
            ]);
        }

    }

    public function update(Request $request, $id)
    {
        $rules = array(
            'target_amount' => 'required|numeric'
        );
        $messages = array(
            'target_amount.required' => 'Please enter amount.'
        );
        $validator = Validator::make($request->all(), $rules, $messages);
        if ($validator->fails()) {
            $returnMessage = array(
                'success' => false,
                'errors' => $validator->errors(),
            );
            return response()->json($returnMessage, 403);
        }

        $target = Target::find($id);

        if (!$target) {
            return response()->json([
                'success' => false,
                'message' => 'Sorry, Target with id ' . $id . ' cannot be found',
            ], 200);
        }

        $updated = $target->fill($request->only([
            'note',
            'target_amount',
        ]))->save();

        if ($updated) {
            return response()->json(['success' => true, 'message' => 'Target Updated Successfully']);
        } else {
            return response()->json([
                'success' => false,
                'message' => 'Sorry, target can not be updated',
            ], 200);
        }

    }

    /**
     * Remove the specified resource from storage.
     *
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function destroy($id)
    {
        $target = Target::find($id);

        if (!$target) {
            return response()->json([
                'success' => false,
                'message' => 'Sorry, Client with id ' . $id . ' cannot be found',
            ], 200);
        }

        if ($client->delete()) {
            return response()->json([
                'success' => true,
                'message' => 'Client Deleted Successfully',
            ]);
        } else {
            return response()->json([
                'success' => false,
                'message' => 'Client could not be deleted',
            ], 200);
        }

    }

    public function getDownstreamLocationAreaIDs($user)
    {
        $user_data_with_locations = LocationArea::where('id', '=', $user->location_area_id)->first();

        if ($user_data_with_locations->location_level_id == 5) {
            //this is SAAO block id
            $block_id = $user_data_with_locations->id;
            return $block_id;
        } else {

            //Need all SAAO under this person

            //get id where parent_id =$catId
            function getOneLevel($catId)
            {

                $query = DB::table('location_areas')
                    ->select(DB::raw('id , location_level_id'))
                    ->where('parent_id', '=', $catId)
                    ->get();

                $resultArray = json_decode(json_encode($query), true);

                $cat_id = array();
                if (count($resultArray) > 0) {

                    foreach ($resultArray as $key => $value) {
                        $cat_id[] = $value;
                    }

                }
                return $cat_id;
            }
            //end getOneLevel

            //get all children based on parent id
            function getChildren($parent_id)
            {
                $tree = array();
                if (!empty($parent_id)) {

                    $tree = getOneLevel($parent_id);
                    foreach ($tree as $key => $val) {
                        $ids = getChildren($val);
                        $tree = array_merge($tree, $ids);
                    }
                }
                return $tree;
            }
            //end getChildren function

            $sdfdsfd = getChildren($user_data_with_locations->id);
            $data = array();
            for ($i = 0; $i < count($sdfdsfd); $i++) {
                    $data[] = $sdfdsfd[$i]['id'];                

            };

            return $data;
        } //end else block

        return $sdfdsfd;

    }
    
}

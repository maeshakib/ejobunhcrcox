<?php

namespace App\Http\Controllers;

use DB;
use Validator;
use App\LocationArea;
use App\Target;
use App\Sale;
use App\Collection;
use App\User;
use Illuminate\Http\Request;

class ReportingController extends Controller
{
    public function MIO_activity(Request $request)
    {

           // validate incoming request
        
           $validator = Validator::make($request->all(), [
            'email' => 'required|email|unique:users',
            'name' => 'required|string|max:50',
            'password' => 'required'
        ]);
         
        if ($validator->fails()) {
             return $validator->errors();
        }
             
        // finally store our user
         
     
        $rules = array(
            'from_date' => 'required|date'
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
        $date = new \DateTime($request->from_date);
        $from_date= $date->format('Y-m-01');
        $to_date = $date->format('Y-m-t');
        $sales = DB::select(
            'SELECT u.id, u.name, la.name as territory, s.sales_date, sum(s.sales_amount) as sale
                FROM users u
                LEFT JOIN sales s ON u.id = s.user_id AND s.sales_date BETWEEN :from_date AND :to_date
                LEFT JOIN location_areas la ON u.location_area_id = la.id
                WHERE u.supervisor_id = :supervisor_id
                GROUP BY u.id, s.sales_date', 
                ['from_date' => $from_date,
                'to_date' => $to_date,
                'supervisor_id' => $user->id]);

        $users =  User::with(['location_area:id,name',
            'sales' => function($q) use($from_date,$to_date)
            {
                $q->whereBetween('sales_date',[$from_date,$to_date]);
                $q->groupBy(['user_id','sales_date']);
                $q->select(['id', 'user_id','sales_date', DB::raw('sum(sales_amount) as amount')]);
            },
            'collections' => function($q) use($from_date,$to_date)
            {
                $q->whereBetween('collection_date',[$from_date,$to_date]);
                $q->groupBy(['user_id','collection_date']);
                $q->select(['id', 'user_id','collection_date', DB::raw('sum(collection_amount) as amount')]);
            },
            'attendance' => function($q) use($from_date,$to_date)
            {
                $q->whereBetween('date',[$from_date,$to_date]);
                $q->select(['id', 'user_id','date', 'cin_time', 'cout_time']);
            },
            'sales_target' => function($q) use($from_date,$to_date)
            {
                $q->where('from_date', '>=', $from_date);
                $q->where('to_date', '<=', $to_date);
                $q->select(['id', 'user_id','from_date', 'to_date', 'target_amount']);
            },
            'collection_target' => function($q) use($from_date,$to_date)
            {
                $q->where('from_date', '>=', $from_date);
                $q->where('to_date', '<=', $to_date);
                $q->select(['id', 'user_id','from_date', 'to_date', 'target_amount']);
            }
            ])
            ->where('supervisor_id', $user->id)
            ->get(['id', 'name', 'location_area_id']);

            foreach ($users as $u) {
                $u['total_sale'] = $u->sales->sum('amount');
                $u['total_collection'] = $u->collections->sum('amount');
                $u['total_sales_target'] = $u->sales_target->sum('target_amount');
                $u['total_collection_target'] = $u->collection_target->sum('target_amount');
                $u['key_sales'] = $u->sales->keyBy('sales_date');
                $u['key_collections'] = $u->collections->keyBy('collection_date');
                $u['key_attendance'] = $u->attendance->keyBy('date');
                unset($u['sales']);
                unset($u['collections']);
                unset($u['attendance']);
                unset($u['sales_target']);
                unset($u['collection_target']);
            }

        
        return $users;
    }

    public function getAllSales(Request $request)
    {


        $rules = array(
            'from_date' => 'required|date',
            'to_date' => 'required|date|after_or_equal:from_date',           
        );

        $messages=array(
            'from_date.required' => 'From Date is Required',
            'to_date.required' => 'To Date is Required',
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



        $results = DB::select('SELECT 
        u.id, 
        u.name, 
        ifnull(sum(s.sales_amount),0) as total_sale, 
        su.name as supervisor,
        la.name as location
        from users u
             join sales s on u.id = s.user_id and s.sales_date BETWEEN ? and ?
            left JOIN users su ON u.supervisor_id = su.id
            left join location_areas la on u.location_area_id = la.id
            GROUP BY u.id
            order by total_sale DESC' ,[$request->from_date,$request->to_date]);
            return $results;

    }
    public function getAllCollections(Request $request)
    {
        $rules = array(
            'from_date' => 'required|date',
            'to_date' => 'required|date|after_or_equal:from_date',           
        );

        $messages=array(
            'from_date.required' => 'From Date is Required',
            'to_date.required' => 'To Date is Required',
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

        $results = DB::select('SELECT 
        u.id, 
        u.name, 
        ifnull(sum(c.collection_amount),0) as total_collection, 
        su.name as supervisor,
        la.name as location
        from users u
             join collections c on u.id = c.user_id and c.collection_date BETWEEN ? and ?
            left JOIN users su ON u.supervisor_id = su.id
            left join location_areas la on u.location_area_id = la.id
            GROUP BY u.id order by total_collection DESC' ,[$request->from_date,$request->to_date]);
            return $results;

    }
    public function aMWiseSales(Request $request)
    {
        $rules = array(
            'from_date' => 'required|date',
            'to_date' => 'required|date|after_or_equal:from_date',           
            // 'user_id' => 'required|exists:users,id',           
        );

        $messages=array(
            'from_date.required' => 'From Date is Required',
            'to_date.required' => 'To Date is Required',
            // 'user_id.required' => 'Select a User',
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
        $user= auth('api')->user();

        $users = DB::select('select      
                                 p1.id 
                                    from        users p1
                                    left join   users p2 on p2.id = p1.supervisor_id 
                                    left join   users p3 on p3.id = p2.supervisor_id 
                                    left join   users p4 on p4.id = p3.supervisor_id  
                                    left join   users p5 on p5.id = p4.supervisor_id  
                                    left join   users p6 on p6.id = p5.supervisor_id
                                    where      ? in (p1.supervisor_id, 
                                                p2.supervisor_id, 
                                                p3.supervisor_id, 
                                                p4.supervisor_id, 
                                                p5.supervisor_id, 
                                                p6.supervisor_id)' ,[$user->id]);

                        foreach ($users as $key => $value) {
                        $data[]= $key;
                        }
                        $users_arr = join(",",$data);

                $results = DB::select('SELECT 
                u.id, 
                u.name, 
                ifnull(sum(s.sales_amount),0) as total_sale, 
                su.name as supervisor,
                la.name as location
                from users u
                    join sales s on u.id = s.user_id and s.sales_date BETWEEN ? and ?
                    left JOIN users su ON u.supervisor_id = su.id
                    left join location_areas la on u.location_area_id = la.id
                    WHERE u.supervisor_id IN('.$users_arr.') 

                    GROUP BY u.id order by total_sale' ,[$request->from_date,$request->to_date]);
                    return $results;

    }
    public function aMWiseCollections(Request $request)
    {

        $rules = array(
            'from_date' => 'required|date',
            'to_date' => 'required|date|after_or_equal:from_date',           
            // 'user_id' => 'required|exists:users,id',           
        );

        $messages=array(
            'from_date.required' => 'From Date is Required',
            'to_date.required' => 'To Date is Required',
            // 'user_id.required' => 'Select a User',
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
        $user= auth('api')->user();

        $users = DB::select('select      
                                 p1.id 
                                    from        users p1
                                    left join   users p2 on p2.id = p1.supervisor_id 
                                    left join   users p3 on p3.id = p2.supervisor_id 
                                    left join   users p4 on p4.id = p3.supervisor_id  
                                    left join   users p5 on p5.id = p4.supervisor_id  
                                    left join   users p6 on p6.id = p5.supervisor_id
                                    where      ? in (p1.supervisor_id, 
                                                p2.supervisor_id, 
                                                p3.supervisor_id, 
                                                p4.supervisor_id, 
                                                p5.supervisor_id, 
                                                p6.supervisor_id)' ,[$user->id]);

                        foreach ($users as $key => $value) {
                        $data[]= $key;
                        }
                        $users_arr = join(",",$data);
//return $data;
                    $results = DB::select('SELECT 
                    u.id, 
                    u.name, 
                    ifnull(sum(c.collection_amount),0) as total_collection, 
                    su.name as supervisor,
                    la.name as location
                    from users u
                        join collections c on u.id = c.user_id and c.collection_date BETWEEN ? and ?
                        left JOIN users su ON u.supervisor_id = su.id
                        left join location_areas la on u.location_area_id = la.id
                        WHERE u.supervisor_id IN('.$users_arr.') 

                        GROUP BY u.id order by total_collection DESC ',[$request->from_date,$request->to_date]);
                        return $results;

    }
    
}

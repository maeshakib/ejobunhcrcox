<?php

namespace App\Http\Controllers;
use DB;
use App\LocationArea;
use App\User;
use App\Target;
use Validator;
use App\Sale;
use App\Collection;
use App\Client;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class SaleController extends Controller
{

    public function index(Request $request)
    {
        
        $rules = array(
            'from_date' => 'required|date',
            'to_date' => 'required|date|after_or_equal:from_date',
            'type' => 'required|numeric|between:0,2',
            
        );
        $messages=array(
            'from_date.required' => 'Please select a Date.',
            'type.required' => 'Please  select a Type.',
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
        $summary_sales=0;
        $summary_collections=0;

        if(!isset($request->to_date)){
            $to_date =$request->from_date;
        }else{
            $to_date =$request->to_date;
        }
        
        $from_date= $request->from_date;
        $type =$request->type;                
        $user = auth('api')->user();
        if($type == 0){ //get sales date range
            $clients = Client::with(['location:id,name','sales' 
                => function($q) use($from_date,$to_date)
                {
                    $q->whereBetween('sales_date',[$from_date,$to_date])->orderBy('sales_date','desc');
                }
                ])
                ->where('user_id', $user->id)
                ->get(['id', 'name', 'address', 'location_area_id']);

                foreach ($clients as $client) 
                {
                    //return $client;
                    $client['total_sales'] = $client->sales->sum('sales_amount');
                    $client['last_sales_date'] = $client->sales->max('sales_date');
                    $summary_sales += $client['total_sales']; //to show as summary sales                      
                    unset($client['sales']);

                }
            
                $summary_object['summary_sales']=$summary_sales;             
                $data['clients']=$clients->where('total_sales','!=', 0)->values();
                $data['summary']=$summary_object;
                return response()->json($data, 200);

        }
        else if($type == 1)
        {
            //get collections date range
            $clients = Client::with(['location:id,name','sales'
            => function($query)  {
                $query->with('location_area');
                }
            ,  'sales.collections'
            => function($q) use($from_date,$to_date)
                {
                    $q->whereBetween('collection_date',[$from_date,$to_date]);
                }
            ])
            ->where('user_id', $user->id)
            ->get(['id', 'name', 'address', 'location_area_id']);
            //return $clients;
            foreach ($clients as $client) 
            {
                
                $c_total_collect = 0;
                foreach ($client->sales as $sale) 
                {
                    $sale['total_collection'] = $sale->collections->sum('collection_amount');
                    $sale['last_collect'] = $sale->collections->max('collection_date');
                    //$sale['sales_address'] = $client->address;
                    $c_total_collect += $sale['total_collection'];
                }
                $client['total_collections'] = $c_total_collect;
                $client['last_collection_date'] = $client->sales->max('last_collect');
                if($client['total_collections']>0){
                    $summary_sales += $client['total_sales']; //to show as summary sales

                }
                $summary_collections += $client['total_collections']; //to show as summary collections
                unset($client['sales']);

            }
            $data['clients']=$clients->where('total_collections','!=', 0)->values();

            //$summary_object['summary_sales']=$summary_sales;
            $summary_object['summary_collections']=$summary_collections;

            $data['summary']=$summary_object;
            
            
            return response()->json($data, 200);

        }
        else //($type == 2)
        { //get collections date range
            $clients = Client::with(['location:id,name',
            'sales' => function($q) use($from_date,$to_date)
            {
                $q->whereBetween('sales_date',[$from_date,$to_date])->orderBy('sales_date','desc');
            },
            
            ])
            ->where('user_id', $user->id)
            ->get(['id', 'name', 'address', 'location_area_id']); 

            $collections = Collection::join('sales', 'collections.sales_id', '=', 'sales.id')
                            ->join('clients', 'clients.id', '=', 'sales.client_id')
                            ->where('sales.user_id', $user->id)
                            ->whereBetween('collection_date',[$from_date,$to_date])
                            ->get(['collections.*', 'sales.id as sales_id', 
                            'clients.name as client_name',
                            'clients.id as client_id'])
                            ->groupBy('client_id');
            //return $collections;
            
            
            $sales_summery = 0;
            $collection_summery = 0;
            foreach ($clients as $key => $client) 
            {
                $client['total_sales'] = $client['sales']->sum('sales_amount');
                $client['last_sales_date'] = $client['sales']->max('sales_date');
                unset($client['sales']);
                if($collections->has($client->id)){
                    $client['total_collections'] = $collections[$client->id]->sum('collection_amount');
                    $client['last_collection_date'] = $collections[$client->id]->max('collection_date');
                }
                else{
                    $client['total_collections'] = 0;
                    $client['last_collection_date'] = null;
                }
                $sales_summery += $client['total_sales'];
                $collection_summery += $client['total_collections'];
                if($client['total_sales'] == 0 && $client['total_collections'] == 0){
                    unset($clients[$key]);
                }

            }

            $data['summary'] = collect(['summary_sales' => $sales_summery,
                                        'summary_collections' => $collection_summery]);

            $data['clients'] = $clients->flatten();
        
            return response()->json($data, 200);

        }



        

        
            
    }
   

    public function singleClientSales(Request $request)
    {
        $user = auth('api')->user();
        $rules = array(
            'from_date' => 'required|date',
            'to_date' => 'required|date|after_or_equal:from_date',
            'type' => 'required|numeric|between:0,2',
            'client_id' => [
                'required',
                Rule::exists('clients','id')->where(function ($query) use($user) {
                    $query->where('user_id', $user->id);
                }),
            ]
            
        );
        $messages=array(
            'from_date.required' => 'Please select a Date.',
            'type.required' => 'Please  select a Type.',
            'client_id.required' => 'Please  select a Client.',
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
        //return $user;
        $summary_sales=0;
        $summary_collections=0;
        if(!isset($request->to_date)){
            $to_date =$request->from_date;
        }else{
            $to_date =$request->to_date;
        }

        $from_date= $request->from_date;
        $type =$request->type;
        $client_id=$request->client_id;

        if($type == 0)
        { //get sales date range
            $client = Client::with(['location:id,name', 'sales' 
            => function($q) use($from_date,$to_date)
            {
                $q->whereBetween('sales_date',[$from_date,$to_date])
                ->orderBy('sales_date','desc')->select(['id','sales_amount', 'sales_date','payment_status', 'client_id']);
            }])
            ->where(['user_id' => $user->id, 'id' => $client_id])
            ->first(['id', 'name', 'address', 'location_area_id', 'user_id']);
            $client['total_sales']= $client->sales->sum('sales_amount');
            $client['success']= true;
            
            return response()->json($client, 200);

        }
        else if($type ==1)
        { //get collections date range
            
            $data = DB::select('SELECT 
            cl.id,
            cl.name,
            cl.address,
            l.name as location,
            l.id as location_id,
            s.id as sales_id,
            s.sales_date,
            s.sales_amount,
            s.payment_status,
            s.invoice_no, 
            MAX(c.collection_date) as max_d, 
            ifnull(sum(c.collection_amount), 0) AS col_amt 
            FROM clients cl
                left join sales s ON s.client_id = cl.id AND s.user_id = :user_id
                left join collections c ON c.sales_id = s.id AND c.collection_date BETWEEN :from_date AND :to_date
                left JOIN location_areas l on cl.location_area_id = l.id
                where cl.id = :client_id
                GROUP BY sales_id', 
                ['user_id' => $user->id, 
                'client_id' => $request->client_id,
                'from_date' => $request->from_date,
                'to_date' => $request->to_date]);
            //return $data;
            
            $client = collect(['id' => $data[0]->id,
                        'name' => $data[0]->name,
                        'address' => $data[0]->address,
                        'location' => collect(['id' => $data[0]->location_id,'name' => $data[0]->location])
                        ]);
            $sales = [];
            $summary = 0;
            foreach ($data as $key => $value) {
                if ($value->col_amt > 0) {
                    $sales[] = ['id' => $value->sales_id,
                            'payment_status' => $value->payment_status,
                            'invoice_no' => $value->invoice_no,
                            'last_collection_date' => $value->max_d,
                            'sales_date' => $value->sales_date,
                            'sales_amount' => $value->sales_amount,
                            'total_collections' => $value->col_amt
                            ];
                    $summary += $value->col_amt;
                }
                
            }
            $client['total_collections'] = $summary;
            $client['sales'] = $sales;
            $client['success']= true;
            return response()->json($client, 200);

        }    

        else if($type == 2)
        { //get both date range
            $client = Client::with(['location:id,name'])->find($request->client_id,['id', 'name', 'address', 'location_area_id']); 

            $data = DB::select('SELECT 
                s.id as id,
                s.sales_date,
                case WHEN sales_date BETWEEN :from_date AND :to_date
                THEN sales_amount ELSE 0 end as sales_amount,
                s.payment_status,
                s.invoice_no, 
                MAX(c.collection_date) as last_collection_date, 
                ifnull(sum(c.collection_amount), 0) AS total_collections
                FROM sales s                
                    left join collections c ON c.sales_id = s.id AND collection_date BETWEEN :from_date2 AND :to_date2
                    where s.client_id = :client_id and s.user_id = :user_id
                    GROUP BY s.id',
            ['user_id' => $user->id, 
            'client_id' => $request->client_id,
            'from_date' => $request->from_date,
            'from_date2' => $request->from_date,
            'to_date' => $request->to_date,
            'to_date2' => $request->to_date]);
            $sales = collect([]);
            foreach ($data as $key => $value) {
                if ($value->sales_amount != 0 || $value->total_collections != 0) {
                    $sales->push($value);
                }
            }
            $client['total_sales'] = $sales->sum('sales_amount');
            $client['total_collections'] = $sales->sum('total_collections');
            $client['sales'] = $sales;
            $client['success']= true;
            return response()->json($client, 200);

        }
        



        
            
    }
    
    public function store(Request $request)
    {

        $rules = array(
            'client_id' => 'required|exists:clients,id',
            'invoice_no' => 'required',
            'sales_amount' => 'required|numeric',
            'sales_date' => 'required|date',
            'invoice_no' =>     'required|unique:sales',
        );
        $messages=array(
            'name.required' => 'Please enter a Name.',
            'invoice_no.required' => 'Please enter a Invoice.',
            'sales_amount.required' => 'Please enter amount.',
            'sales_date.required' => 'Please select a Name.',
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

        $sales = new Sale;
        $sales->client_id = $request->client_id;
        $sales->invoice_no = $request->invoice_no;
        $sales->sales_amount = $request->sales_amount;
        $sales->sales_date = $request->sales_date;
        $sales->user_id =$user->id;
        $sales->location_area_id = $user->location_area_id;
        $sales->sales_note = $request->sales_note;
        if(isset($request->collection_amount) && ($request->collection_amount == $request->sales_amount)){
            $sales->payment_status = 1; //paid
        }
        if(isset($request->collection_amount) && ($request->collection_amount>0 || ($request->collection_amount < $request->sales_amount))){
            $sales->payment_status = 2; //partial paid
        }
        if(isset($request->collection_amount) && ($request->collection_amount == 0)){
            $sales->payment_status = 0; //un paid
        }
        
         $sales->edit_status = 0;
         $sales->save();
       
        if ($sales->id)
        {           
            //check collection value exist
            if($request->has('collection_amount') && ($request->collection_amount > 0)){
                $colletion = new Collection;
                $colletion->sales_id = $sales->id;
                $colletion->collection_amount = $request->collection_amount;
                $colletion->collection_date = $request->sales_date;
                $colletion->user_id = $user->id;

                $colletion->save();
                if ($colletion->id)
                {
                    return response()->json(['success' => true, 'message' =>'Sales and Collection Saved Successfully '], 200); 
                }else{
                    return response()->json(['success' => false, 'message' =>'Sales Information Saved but Collection has not been Saved '], 200);
                }
            }else{
                return response()->json(['success' => true, 'message' =>'Sales Saved Successfully '], 200); 
            }

        }else{
            return response()->json(['success' => false, 'message' =>'Sales Information has not been Saved '], 200);
        }
    }

    public function show($id)
    {
        //sales with collection and location area
        $sales = Sale::with('collections:id,sales_id,collection_amount,collection_date','location_area:id,name,lat_lng,map_data,description,parent_id,location_level_id','clients:id,name,address') 
        ->select('id','client_id','invoice_no','sales_amount','sales_date','user_id','sales_note','payment_status','edit_status','location_area_id')->whereIn('id',[$id])->first();

        if (!$sales) 
        {
            return response()->json([
                'success' => false,
                'message' => 'Sorry, Sales with id ' . $id . ' cannot be found'
            ], 200);
        }else
        {
            $sales['client_name']=$sales->clients->name;
            $sales['client_address']=$sales->clients->address;
            $sales['paid_amount']=$sales->collections->sum('collection_amount');
            unset($sales->clients);
            return response()->json($sales, 200);

           
        }

    }


    public function update(Request $request, $id)
    {

        $sales = Sale::with('collections')->find($id);
        $collected = $sales->collections->sum('collection_amount');
        $remaining = $sales->sales_amount - $collected;
        $user = auth('api')->user();
        //return $remaining;

        $rules = array(
            'client_id' => 'required|exists:clients,id',            
            'invoice_no' => 'required',
            'collection_amount' => 'numeric|max:'.$remaining
        );
        $messages=array(
            'client_id.required' => 'Please select a client',
            'invoice_no.required' => 'Please enter a Invoice.',
            'collection_amount.max' => 'Remaining Amount is '. $remaining
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
      
        if (!$sales) {
            return response()->json([
                'success' => false,
                'message' => 'Sorry, Collection with id ' . $id . ' cannot be found'
            ], 200);
        }
        $sales->fill($request->only([
            'client_id',
            'invoice_no',
            'sales_note',
        ]));
        $sales->client_id = $request->client_id;
        $sales->invoice_no = $request->invoice_no;
        $sales_param=$sales->save();
         //check collection value exist
         if($request->has('collection_amount')){
            $last_salse=$request->collection_amount+$collected;

            $colletion = new Collection;
            $colletion->sales_id = $id;
            $colletion->collection_amount = $request->collection_amount;
            $colletion->collection_date = $request->collection_date;
            $colletion->collection_note = $request->collection_note;
            $colletion->user_id = $user->id;
            $colletion->save();
            if ($colletion->id && $sales_param)
            {

                if($last_salse == $sales->sales_amount){
                    $sales->payment_status = 1; //paid
                }
                if($last_salse < $sales->sales_amount){
                    $sales->payment_status = 2; //partial paid
                }
                if($last_salse == 0){
                    $sales->payment_status = 0; //un paid
                }
            $sales->save();


                return response()->json(['success' => true, 'message' =>'Sales Updated and Collection Saved Successfully '], 200); 
            }else{
                return response()->json(['success' => false, 'message' =>'Sales Information Updated but Collection has not been Updated '], 200);
            }
        }elseif($sales_param){
            return response()->json(['success' => true, 'message' =>'Sales Updated  Successfully '], 200); 

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

    public function addCollection(Request $request, $sales_id)
    {
        $user = auth('api')->user();
        $sales = Sale::with('collections')->find($sales_id);
        if(!$sales){
            $returnMessage = array(
                'success' => false,
                'errors' => 'Invalid Sales id',
                );
            return response()->json($returnMessage, 200);
        }
        $collected = $sales->collections->sum('collection_amount');
        $remaining = $sales->sales_amount - $collected;
        $rules = array(          
            'collection_amount' => 'required|numeric|max:'.$remaining,
            'collection_note' => 'present',
            'collection_date' => 'required|date'
        );
        $messages=array(
            'amount.required' => 'Please select amount',
            'invoice_no.required' => 'Please enter a Invoice.',
            'collection_amount.max' => 'Remaining Amount is '. $remaining
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

        $collection = new Collection($request->only(['collection_amount','collection_note','collection_date']));
        $collection->sales_id =$sales_id;
        $collection->user_id =$user->id;
        $collection->save();

        $returnMessage = array(
            'success' => true,
            'message' => 'saved Successfully',
            );
        return response()->json($returnMessage, 200);

    }

}

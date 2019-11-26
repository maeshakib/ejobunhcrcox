<?php

namespace App;

use Illuminate\Database\Eloquent\Model;

class Sale extends Model
{

    protected $fillable = [
        'client_id'
    ];
    protected $table = 'sales';

    public function collections()
    {
        return $this->hasMany('App\Collection' ,'sales_id');
    }

    public function users()
    {
        return $this->belongsTo('App\User');
    }

    public function clients()
    {
        return $this->belongsTo('App\Client','client_id');
    }
    
    public function location_area()
    {
        return $this->belongsTo('App\LocationArea', 'location_area_id');
    }

}

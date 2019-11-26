<?php

namespace App;

use Illuminate\Database\Eloquent\Model;

class Client extends Model
{
    protected $fillable = [
        'name', 'user_id',
    ];

  

    public function users()
    {
        return $this->belongsTo('App\User');
    }
    public function sales()
    {
        return $this->hasMany('App\Sale','client_id');
    }

    public function location()
    {
        return $this->belongsTo('App\LocationArea', 'location_area_id');
    }
}

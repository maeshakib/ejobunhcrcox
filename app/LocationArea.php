<?php

namespace App;

use Illuminate\Database\Eloquent\Model;

class LocationArea extends Model
{
    protected $fillable = ['name', 'parent_id', 'level', 'lat_lng', 'map_data', 'location_level_id', 'description'];
    public function location_levels()
    {
        return $this->belongsTo('App\LocationLevel', 'location_level_id');
    }
    public function parent()
    {
        return $this->belongsTo('App\LocationArea', 'parent_id');
    }
    public function parents()
    {
        return $this->belongsTo('App\LocationArea', 'parent_id')->with('parents:id,name,parent_id');
    }
    

    public function children()
    {
        return $this->hasMany('App\LocationArea', 'parent_id');
    }

    
    public function sales()
    {
            return $this->hasMany('App\Sale');
    }


    public function users()
    {
        return $this->belongsTo(User::class);
    }

 

    public function allChildren()
    {
        return $this->hasMany('App\LocationArea', 'parent_id')->with('allChildren');
    }

}

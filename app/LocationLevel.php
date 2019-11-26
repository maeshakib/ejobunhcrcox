<?php

namespace App;

use Illuminate\Database\Eloquent\Model;

class LocationLevel extends Model
{
    public function location_area()
    {
        return $this->hasMany('App\LocationArea', 'location_level_id');
    }
}

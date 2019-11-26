<?php

namespace App;

use Illuminate\Database\Eloquent\Model;

class Designation extends Model
{
    protected $fillable = [
        'name', 'description'
    ];
    public function users()
    {
        return $this->hasMany(User::class);
    }
}

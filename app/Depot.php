<?php

namespace App;

use Illuminate\Database\Eloquent\Model;

class Depot extends Model
{
    protected $fillable = [
        'name', 'description'
    ];
    public function users()
    {
        return $this->hasMany(User::class);
    }
}

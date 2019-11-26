<?php

use Illuminate\Support\Facades\Schema;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Database\Migrations\Migration;

class CreateClientsTable extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::create('clients', function (Blueprint $table) {
            $table->increments('id');
            $table->string('name',200);
            $table->string('conatct_no',100)->nullable();
            $table->string('lat_lng')->nullable();
            $table->string('address')->nullable();
            $table->string('description')->nullable();
            $table->unsignedInteger('user_id');
            $table->unsignedInteger('location_area_id');
            $table->tinyInteger('status')->nullable()
            ->comment('1=active,0=inactive');
            $table->timestamps();

            $table->foreign('user_id')->references('id')->on('users');
            $table->foreign('location_area_id')->references('id')->on('location_areas');
        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::dropIfExists('clients');
    }
}

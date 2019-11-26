<?php

use Illuminate\Support\Facades\Schema;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Database\Migrations\Migration;

class CreateUsersTable extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::create('users', function (Blueprint $table) {
            $table->increments('id');
            $table->string('name');
            $table->string('email')->unique();
            $table->string('password');
            $table->integer('role_id')->unsigned();
            $table->string('mobile_no', 20)->nullable();
            $table->string('photo', 200)->nullable();
            $table->integer('designation_id')->unsigned();
            $table->integer('department_id')->unsigned()->nullable();
            $table->tinyInteger('gender')->nullable()->nullable();
            $table->integer('location_area_id')->unsigned();
            $table->string('national_identification_num',20)->nullable();         
            $table->integer('carry_leaves')->default(0);         
            $table->date('join_date')->nullable();          
            $table->unsignedInteger('supervisor_id')->nullable();          
            $table->rememberToken()->nullable();
            $table->string('description',600)->nullable(); 
            $table->string('address',300)->nullable();
            $table->tinyInteger('status')->nullable();
            $table->string('online',10)->nullable();
            $table->text('socket_id')->nullable();
            $table->tinyInteger('is_supervisor')->default(0);
            $table->softDeletes();
            $table->timestamps();
            $table->foreign('role_id')->references('id')->on('roles');
            $table->foreign('location_area_id')->references('id')->on('location_areas');
            $table->foreign('designation_id')->references('id')->on('designations');
            $table->foreign('department_id')->references('id')->on('departments');
        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::dropIfExists('users');
    }
}

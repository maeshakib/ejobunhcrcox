<?php

use Illuminate\Support\Facades\Schema;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Database\Migrations\Migration;

class CreateCollectionsTable extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::create('collections', function (Blueprint $table) {
            $table->increments('id');
            $table->integer('sales_id')->unsigned();
            $table->float('collection_amount', 20, 2);
            $table->dateTime('collection_date')->nullable();     
            $table->string('collection_note')->nullable();    
            $table->unsignedInteger('user_id'); 
            $table->timestamps();
            
            $table->foreign('sales_id')->references('id')
            ->on('sales')
            ->onDelete('cascade');
            $table->foreign('user_id')->references('id')->on('users');

        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::dropIfExists('collections');
    }
}

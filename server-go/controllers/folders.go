package controllers

import (
	"net/http"
	"strings"
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
)

type FolderHandler struct { DB *pgxpool.Pool }
func userID(c *gin.Context) (string, bool) { v, ok := c.Get("userID"); s, sok := v.(string); return s, ok && sok }
func (h FolderHandler) List(c *gin.Context) { uid, ok := userID(c); if !ok { c.JSON(401,gin.H{"message":"鐧诲綍宸插け鏁?}); return }; rows,err:=h.DB.Query(c.Request.Context(),`SELECT f.id,f.name,COUNT(d.id)::int FROM folders f LEFT JOIN favorite_details d ON d.folder_id=f.id WHERE f.user_id=$1 GROUP BY f.id ORDER BY f.created_at`,uid); if err!=nil { c.JSON(500,gin.H{"message":"鏈嶅姟鍣ㄥ唴閮ㄩ敊璇?}); return }; defer rows.Close(); result:=[]gin.H{}; for rows.Next(){var id int64;var name string;var count int; if rows.Scan(&id,&name,&count)==nil {result=append(result,gin.H{"id":id,"name":name,"itemCount":count})} }; c.JSON(200,gin.H{"folders":result}) }
func (h FolderHandler) Create(c *gin.Context) { uid,ok:=userID(c);if !ok {c.JSON(401,gin.H{"message":"鐧诲綍宸插け鏁?});return};var in struct{Name string `json:"name"`};if c.ShouldBindJSON(&in)!=nil||strings.TrimSpace(in.Name)==""{c.JSON(400,gin.H{"message":"鏀惰棌澶瑰悕绉颁笉鑳戒负绌?});return};var id int64;err:=h.DB.QueryRow(c.Request.Context(),`INSERT INTO folders(user_id,name) VALUES($1,$2) RETURNING id`,uid,strings.TrimSpace(in.Name)).Scan(&id);if err!=nil{c.JSON(409,gin.H{"message":"鏀惰棌澶瑰悕绉板凡瀛樺湪"});return};c.JSON(http.StatusCreated,gin.H{"folder":gin.H{"id":id,"name":strings.TrimSpace(in.Name),"itemCount":0}})}

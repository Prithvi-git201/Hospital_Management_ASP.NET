using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using DBProject.DAL;
using System.Data;

namespace doctor
{
    public partial class Historyupdate : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {

        }

        public void saveindatabase(object sender, EventArgs e)
        {
            myDAL objmyDAL = new myDAL();
            int found;
            // Distributed Redis-backed session (ElastiCache on EKS) - safe null-checked access
            int did = Session["idoriginal"] != null ? (int)Session["idoriginal"] : 0;
            string disease= Disease.Text;
            string progres = progress.Text;
            string prescrip = Prescription.Text;

            // Distributed Redis-backed session (ElastiCache on EKS) - safe null-checked access
            int appid = Session["appointid"] != null ? (int)Session["appointid"] : 0;

            
            found = objmyDAL.update_prescription_DAL(did,appid,disease,progres,prescrip);

            if (found != 1)
            { Response.Write("<script>alert('There was some error');</script>"); }
            else
            {
                { Response.Write("<script>alert('Information Successfully Updated');</script>"); }
            }
        }


        public void generate_bill(object sender, EventArgs e)
        {
            Response.Redirect("bill.aspx");
        }
    }
}
